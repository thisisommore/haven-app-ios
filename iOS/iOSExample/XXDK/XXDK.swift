//
//  XXDK.swift
//  iOSExample
//
//  Created by Richard Carback on 3/6/24.
//

import Bindings
import Foundation
import Kronos
import SwiftData
import SwiftUI

// NDF is the configuration file used to connect to the xx network. It
// is a list of known hosts and nodes on the network.
// A new list is downloaded on the first connection to the network
public var MAINNET_URL =
    "https://elixxir-bins.s3.us-west-1.amazonaws.com/ndf/mainnet.json"

let XX_GENERAL_CHAT =
    "<Speakeasy-v3:xxGeneralChat|description:Talking about the xx network|level:Public|created:1674152234202224215|secrets:rb+rK0HsOYcPpTF6KkpuDWxh7scZbj74kVMHuwhgUR0=|RMfN+9pD/JCzPTIzPk+pf0ThKPvI425hye4JqUxi3iA=|368|1|/qE8BEgQQkXC6n0yxeXGQjvyklaRH6Z+Wu8qvbFxiuw=>"

// This resolves to "Resources/mainnet.crt" in the project folder for iOSExample
public var MAINNET_CERT =
    Bundle.main.path(forResource: "mainnet", ofType: "crt")
    ?? "unknown resource path"
enum MyError: Error {
    case runtimeError(String)
}

/// Callback for file download progress (file storage is handled by EventModel.updateFile)
class FileDownloadCallback: FtReceivedProgressCallback {
    private let messageId: String
    
    init(messageId: String) {
        self.messageId = messageId
    }
    
    func callback(payload: Data, fileData: Data?, partTracker: Any?, error: Error?) {
        if let error = error {
            print("[FT] Download error for \(messageId): \(error.localizedDescription)")
            return
        }
        
        // Parse progress - file storage is handled automatically by SDK via EventModel.updateFile
        if let progress = try? JSONDecoder().decode(FtReceivedProgress.self, from: payload) {
            print("[FT] Download progress for \(messageId): \(progress.received)/\(progress.total)")
            if progress.completed {
                print("[FT] Download completed for \(messageId)")
            }
        }
    }
}

/// Progress info for file download
struct FtReceivedProgress: Codable {
    let completed: Bool
    let received: Int
    let total: Int
}

// Identity object structure for generated identities
public struct GeneratedIdentity {
    public let privateIdentity: Data
    public let codename: String
    public let codeset: Int
    public let pubkey: String
}

public class XXDK: XXDKP {
    public func progress(_ status: XXDKProgressStatus) async {
        await MainActor.run {
            withAnimation {
                self.status = status.message
                
                // Handle special case: .final forces 100%
                if status.increment == -1 {
                    self.statusPercentage = 100.0
                } else {
                    // Increment the percentage, capping at 100
                    self.statusPercentage = min(self.statusPercentage + status.increment, 100.0)
                }
            }
        }
    }


    private var downloadedNdf: Data?
    private var nsLock = NSLock()
    private func lockTask() {
        nsLock.lock()
    }

    private func unlockTask() {
        nsLock.unlock()
    }
    @Published var status: String = "..."
    @Published var statusPercentage: Double = 0
    @Published var codename: String?
    var codeset: Int = 0
    private var isNewUser: Bool = false
    // Channels Manager retained for channel sends
    private var channelsManager: Bindings.BindingsChannelsManager?
    private var stateDir: URL

    private var storageTagListener: RemoteKVKeyChangeListener?
    private var remoteKV: Bindings.BindingsRemoteKV?
    var cmix: Bindings.BindingsCmix?
    var DM: Bindings.BindingsDMClient?
    // This will not start receiving until the network follower starts
    var dmReceiver = DMReceiver()
    var eventModelBuilder: EventModelBuilder?
    // Retained SwiftData model container for lifecycle operations

    private var modelActor: SwiftDataActor?
    // modelContainer and modelActor for receivers/callbacks are injected from SwiftUI (e.g., ContentView.onAppear)

    // Channel UI callbacks for handling channel events
    private let channelUICallbacks: ChannelUICallbacks
    private var sm: SecretManager?
    private var fileDownloadObserver: Any?
    
    public func setModelContainer(mActor: SwiftDataActor, sm: SecretManager) {
        // Retain container and actor for lifecycle operations
        self.sm = sm
        self.modelActor = mActor
        // Inject into receivers/callbacks
        self.dmReceiver.modelActor = mActor
        self.channelUICallbacks.configure(modelActor: mActor)
        self.eventModelBuilder?.configure(modelActor: mActor)
        
        // Setup file download observer
        setupFileDownloadObserver()
    }
    
    private func setupFileDownloadObserver() {
        fileDownloadObserver = NotificationCenter.default.addObserver(
            forName: .fileDownloadNeeded,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleFileDownloadNeeded(notification)
        }
    }
    
    private func handleFileDownloadNeeded(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let fileInfoJSON = userInfo["fileInfoJSON"] as? Data,
              let messageId = userInfo["messageId"] as? String else {
            print("[FT] Invalid fileDownloadNeeded notification")
            return
        }
        
        print("[FT] Starting download for message: \(messageId)")
        
        Task {
            do {
                let callback = FileDownloadCallback(messageId: messageId)
                _ = try downloadFile(fileInfoJSON: fileInfoJSON, progressCB: callback, periodMS: 500)
            } catch {
                print("[FT] Download failed: \(error.localizedDescription)")
            }
        }
    }

    init() {
        self.channelUICallbacks = ChannelUICallbacks()

        let netTime = NetTime()
        // xxdk needs accurate time to connect to the live network
        Bindings.BindingsSetTimeSource(netTime)

        // Always create a fresh, unique temp working directory per init
        // e.g., <system tmp>/<UUID> and use "ekv" within it for state
        do {
            let basePath = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            stateDir = basePath.appendingPathComponent("xxAppState")
            if !FileManager.default.fileExists(atPath: stateDir.path) {
                try FileManager.default.createDirectory(
                    at: stateDir,
                    withIntermediateDirectories: true
                )
                isNewUser = true
            }
            stateDir = stateDir.appendingPathComponent("ekv")
               // ⭐ IMPORTANT: Create ekv directory if it doesn't exist
               if !FileManager.default.fileExists(atPath: stateDir.path) {
                   try FileManager.default.createDirectory(
                       at: stateDir,
                       withIntermediateDirectories: true
                   )
                   print("📂 Created ekv directory: \(stateDir.path)")
               }
               
               print("📂 Using ekv directory: \(stateDir.path)")
        } catch let err {
            fatalError(
                "failed to get state directory: " + err.localizedDescription
            )
        }

    }

    func downloadNdf() async {
        lockTask()
        defer { unlockTask() }
        // UX: Friendly staged progress
        await progress(.downloadingNDF)

        // TODO: download this as soon as app starts if cmix is being created first time
        downloadedNdf = downloadNDF(
            url: MAINNET_URL,
            certFilePath: MAINNET_CERT
        )
    }

    func setUpCmix() async {
        lockTask()
        defer { unlockTask() }
        // Always start from a clean SwiftData state per request

        do {
            //                try container.erase()
            print("SwiftData: Deleted all local data at startup")
        } catch {
            print(
                "SwiftData: Failed to delete all data at startup: \(error)"
            )
        }
//        channelsManager.repl
        // Get secret from Keychain
        guard let sm else {
            fatalError("no secret manager")
        }
        let secret = try! sm.getPassword().data
        // NOTE: Empty string forces defaults, these are settable but it is recommended that you use the defaults.
        // Load default cMix params, set EnableImmediateSending, and pass as JSON
        let defaultParamsJSON = Bindings.BindingsGetDefaultCMixParams()
        var params = try! Parser.decodeCMixParams(from: defaultParamsJSON ?? Data())

        // Ensure immediate sending is enabled per user request
        params.Network.EnableImmediateSending = true
        let cmixParamsJSON = try! Parser.encodeCMixParams(params)
        if isNewUser {

            guard let downloadedNdf else {
                fatalError("no ndf downloaded yet")
            }
            await progress(.settingUpCmix)
            var err: NSError?
            Bindings.BindingsNewCmix(
                downloadedNdf.utf8,
                stateDir.path,
                secret,
                "",
                &err
            )
            if let err {
                print(
                    "ERROR: could not create new Cmix: "
                        + err.localizedDescription
                )
                fatalError(
                    "could not create new Cmix: " + err.localizedDescription
                )
            }
        }

        await progress(.loadingCmix)
        var err: NSError?
        let loadedCmix = Bindings.BindingsLoadCmix(
            stateDir.path,
            secret,
            cmixParamsJSON,
            &err
        )
        await MainActor.run {
            cmix = loadedCmix
        }
        if let err {
            print("ERROR: could not load Cmix: " + err.localizedDescription)
            fatalError("could not load Cmix: " + err.localizedDescription)
        }
    }

    func startNetworkFollower() async {
        lockTask()
        defer { unlockTask() }
        guard let cmix else {
            print("ERROR: cmix is not available")
            fatalError("cmix is not available")
        }
        await progress(.startingNetworkFollower)

        print(
            "DMPUBKEY: \(DM?.getPublicKey()?.base64EncodedString() ?? "empty pubkey")"
        )
        print("DMTOKEN: \(DM?.getToken() ?? 0)")

        do {
            try cmix.startNetworkFollower(50000)
            cmix.wait(forNetwork: 10 * 60 * 1000)
        } catch let error {
            print("ERROR: cannot start network: " + error.localizedDescription)
            fatalError("cannot start network: " + error.localizedDescription)
        }
        
        await progress(.networkFollowerComplete)
    }

    func load(privateIdentity _privateIdentity: Data?) async {
        lockTask()
        defer {unlockTask()}
        var err: NSError?
        guard let cmix else {
            print("ERROR: cmix is not available")
            fatalError("cmix is not available")
        }

        await progress(.loadingIdentity)

        let privateIdentity: Data
        if let _privateIdentity {
            do {
                try cmix.ekvSet("MyPrivateIdentity", value: _privateIdentity)
            } catch let error {
                print("ERROR: could not set ekv: " + error.localizedDescription)
                fatalError("could not set ekv: " + error.localizedDescription)
            }
            privateIdentity = _privateIdentity
        } else {
            do {
                privateIdentity = try cmix.ekvGet("MyPrivateIdentity")
            } catch let error {
                print("ERROR: could not set ekv: " + error.localizedDescription)
                fatalError("could not set ekv: " + error.localizedDescription)
            }
        }

        print(
            "Exported Codename Blob: " + privateIdentity.base64EncodedString()
        )

        // Derive public identity JSON from the private identity and decode codename
        let publicIdentity: Data?
        publicIdentity = Bindings.BindingsGetPublicChannelIdentityFromPrivate(
            privateIdentity,
            &err
        )
        if let err {
            print(
                "ERROR: could not derive public identity: "
                    + err.localizedDescription
            )
            fatalError(
                "could not derive public identity: " + err.localizedDescription
            )
        }
        if let pubId = publicIdentity {
            do {
                let identity = try Parser.decodeIdentity(from: pubId)

                await MainActor.run {
                    self.codename = identity.codename
                }

                // Persist codename for later reads
                if let nameData = identity.codename.data(using: .utf8) {
                    do { try cmix.ekvSet("MyCodename", value: nameData) } catch
                    {
                        print(
                            "could not persist codename: \(error.localizedDescription)"
                        )
                    }
                }
            } catch {
                print(
                    "failed to decode public identity json: \(error.localizedDescription)"
                )
            }
        }

        await progress(.creatingIdentity)

        let notifications = Bindings.BindingsLoadNotifications(
            cmix.getID(),
            &err
        )
        if let err {
            print(
                "ERROR: could not load notifications: "
                    + err.localizedDescription
            )
            fatalError(
                "could not load notifications: " + err.localizedDescription
            )
        }

        await progress(.syncingNotifications)

        let receiverBuilder = DMReceiverBuilder(receiver: dmReceiver)

        //Note: you can use `newDmManagerMobile` here instead if you want to work with
        //an SQLite database.
        // This interacts with the network and requires an accurate clock to connect or you'll see
        // "Timestamp of request must be within last 5 seconds." in the logs.
        // If you have trouble shutdown and start your emulator.
        let dmClient = Bindings.BindingsNewDMClient(
            cmix.getID(),
            (notifications?.getID())!,
            privateIdentity,
            receiverBuilder,
            dmReceiver,
            &err
        )
        DM = dmClient
        if let err {
            print(
                "ERROR: could not load dm client: " + err.localizedDescription
            )
            fatalError("could not load dm client: " + err.localizedDescription)
        }

        await progress(.connectingToNodes)

        remoteKV = cmix.getRemoteKV()

        await progress(.settingUpRemoteKV)

        let storageTagListener: RemoteKVKeyChangeListener
        // Start RemoteKV listener for the storage tag during load so it's ready before channel join
        do {
            storageTagListener = try RemoteKVKeyChangeListener(
                key: "channels-storage-tag",
                remoteKV: remoteKV!,
                version: 0,
                localEvents: true
            )
        } catch {
            print("ERROR: failed to set storageTagListener \(error)")
            fatalError("failed to set storageTagListener \(error)")
        }

        await progress(.waitingForNetwork)

        self.storageTagListener = storageTagListener
        // Run readiness + Channels Manager creation in the background, retrying every 2 seconds until success

        do {
           
            let cmixId = cmix.getID()
            // Attempt to create Channels Manager on the MainActor
            var err: NSError?

            await progress(.preparingChannelsManager)

            guard
                let noti = Bindings.BindingsLoadNotificationsDummy(
                    cmixId,
                    &err
                )
            else {
                print("ERROR: BindingsLoadNotificationsDummy returned nil")
                fatalError("BindingsLoadNotificationsDummy returned nil")
            }

            //                let dbPath = channelsDir.appendingPathComponent("channels.sqlite").path

            await MainActor.run {
                eventModelBuilder = EventModelBuilder(
                    model: EventModel()
                )
            }

            if let actor = self.modelActor {
                self.eventModelBuilder?.configure(modelActor: actor)
            }

            // Initialize E2e for file transfer
            await progress(.creatingE2e)
            print("[FT] Creating E2e for file transfer...")
            let receptionIdentity = try cmix.makeReceptionIdentity()
            var e2eErr: NSError?
            guard let e2eObj = BindingsLogin(
                cmix.getID(),
                nil,
                receptionIdentity,
                nil,
                &e2eErr
            ) else {
                print("[FT] ERROR: Failed to create E2e: \(e2eErr?.localizedDescription ?? "unknown")")
                throw e2eErr ?? MyError.runtimeError("[FT] Failed to create E2e")
            }
            self.e2e = e2eObj
            print("[FT] E2e created, ID: \(e2eObj.getID())")
            
            // Initialize ChannelsFileTransfer
            print("[FT] Initializing file transfer...")
            channelsFileTransfer = try ChannelsFileTransfer.initialize(
                e2eID: Int(e2eObj.getID()),
                paramsJson: nil
            )
            print("[FT] File transfer initialized, extension builder ID: \(channelsFileTransfer!.getExtensionBuilderID())")
            
            // Prepare extension builders JSON for ChannelsManager
            let extensionIDs = [channelsFileTransfer!.getExtensionBuilderID()]
            let extensionJSON = try JSONEncoder().encode(extensionIDs)
            print("[FT] Extension builders JSON: \(String(data: extensionJSON, encoding: .utf8) ?? "nil")")

            if isNewUser {
                
                guard
                    let cm = Bindings.BindingsNewChannelsManager(
                        cmix.getID(),
                        privateIdentity,
                        eventModelBuilder,
                        extensionJSON,
                        noti.getID(),
                        channelUICallbacks,
                        &err
                    )
                else {
                    print("ERROR: no cm")
                    fatalError("no cm")
                }
                self.channelsManager = cm
                print("BindingsNewChannelsManager: tag - \(cm.getStorageTag())")
                // Create remote KV entry for channels storage tag
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let storageTagDataJson = try Parser.encodeString(cm.getStorageTag())
                let storageTagData = storageTagDataJson.base64EncodedString()
                let entry = RemoteKVEntry(
                    version: 0,
                    data: storageTagData,
                    timestamp: timestamp
                )
                let entryData = try Parser.encodeRemoteKVEntry(entry)
                print("ed=rkv \(entryData.base64EncodedString())")
                try remoteKV!.set("channels-storage-tag", objectJSON: entryData)
                self.storageTagListener!.data = cm.getStorageTag().data
            } else {
                let storageTagString = self.storageTagListener!.data!.utf8
                print("BindingsLoadChannelsManager: tag - \(storageTagString)")
                let cm = Bindings.BindingsLoadChannelsManager(
                    cmix.getID(),
                    storageTagString,
                    eventModelBuilder,
                    extensionJSON,
                    noti.getID(),
                    channelUICallbacks,
                    &err
                )
                self.channelsManager = cm
            }

            if !isNewUser {
                // Finalize status: ready for new users
                await progress(.readyExistingUser)
                return
            }
            isNewUser = false
            // Update status: joining channels
            await progress(.joiningChannels)
            while true {
                let readyData = try cmix.isReady(0.1)
                let readinessInfo = try Parser.decodeIsReadyInfo(
                    from: readyData
                )
                if !readinessInfo.isReady {
                    print(
                        "cMix not ready yet (howClose=\(readinessInfo.howClose)) — retrying in 2s…"
                    )
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    continue
                } else {
                    break
                }
            }
        } catch {
            fatalError("err \(error)")
        }

        guard let codename, let DM else {
            print("ERROR: codename/DM/modelContainer not there")
            fatalError("codename/DM/modelContainer not there")
        }
        // After loading, if we have a codename, ensure a self chat exists
        if !codename.isEmpty {
            // Use the DM public key (base64) as the Chat.id for DMs
            guard let selfPubKeyData = DM.getPublicKey() else {
                print("ERROR: self pub key data is nil")
                fatalError("self pub key data is nil")
            }
            let selfPubKeyB64 = selfPubKeyData.base64EncodedString()
            do {
                try await MainActor.run {
                    // Check if a DM chat already exists for this public key (id == pubkey b64) using SwiftDataActor
                    guard let actor = self.modelActor else {
                        print("ERROR: modelActor not available")
                        return
                    }
                    let descriptor = FetchDescriptor<Chat>(
                        predicate: #Predicate { $0.id == selfPubKeyB64 }
                    )
                    let existing = try actor.fetch(descriptor)
                    if existing.isEmpty {
                        let token64 = DM.getToken()
                        let tokenU32 = UInt32(truncatingIfNeeded: token64)
                        let selfToken = Int32(bitPattern: tokenU32)
                        let chat = Chat(
                            pubKey: selfPubKeyData,
                            name: "<self>",
                            dmToken: selfToken,
                            color: 0xE97451
                        )
                        actor.insert(chat)
                        try actor.save()
                        print("[XXDK] is ready = true")
                    }
                }
            } catch {
                print(
                    "HomeView: Failed to create self chat for \(codename): \(error)"
                )
            }
        }
        // Ensure initial channel exists locally and join only if not present
        do {
            let cd = try await joinChannel(XX_GENERAL_CHAT)
            let channelId = cd.channelId ?? "xxGeneralChat"
            try await MainActor.run {
                // Check if channel chat exists using SwiftDataActor
                guard let actor = self.modelActor else {
                    print("ERROR: modelActor not available")
                    return
                }
                let check = FetchDescriptor<Chat>(
                    predicate: #Predicate { $0.id == channelId }
                )
                let existingChannel = try actor.fetch(check)
                if existingChannel.isEmpty {
                    let channelChat = Chat(channelId: channelId, name: cd.name)
                    actor.insert(channelChat)
                    try actor.save()
                }
            }
        } catch {
            print(
                "HomeView: Failed to ensure initial channel xxGeneralChat: \(error)"
            )
        }

        // Mark setup as complete
        sm!.isSetupComplete = true
        
        // Finalize status: ready for new users
        await progress(.ready)
    }
    /// Generate multiple channel identities
    /// - Parameter amountOfIdentities: Number of identities to generate
    /// - Returns: Array of GeneratedIdentity objects containing private identity, codename, codeset, and pubkey
    func generateIdentities(amountOfIdentities: Int) -> [GeneratedIdentity] {
        guard let cmix else {
            print("ERROR: cmix is not available")
            return []
        }

        var identities: [GeneratedIdentity] = []
        var err: NSError?

        for _ in 0..<amountOfIdentities {
            // Generate private identity
            let privateIdentity = Bindings.BindingsGenerateChannelIdentity(
                cmix.getID(),
                &err
            )

            guard privateIdentity != nil else {
                print("ERROR: Failed to generate private identity")
                if let error = err {
                    print("Error: \(error.localizedDescription)")
                }
                continue
            }

            guard err == nil else {
                fatalError(
                    "ERROR: Failed to generate private identity: \(err!.localizedDescription)"
                )
            }

            // Derive public identity from private identity
            let publicIdentity =
                Bindings.BindingsGetPublicChannelIdentityFromPrivate(
                    privateIdentity!,
                    &err
                )

            guard publicIdentity != nil else {
                print("ERROR: Failed to derive public identity")
                if let error = err {
                    print("Error: \(error.localizedDescription)")
                }
                continue
            }

            guard err == nil else {
                fatalError(
                    "ERROR: Failed to derive public identity: \(err!.localizedDescription)"
                )
            }

            do {
                // Decode the public identity JSON
                let identity = try Parser.decodeIdentity(from: publicIdentity!)

                // Create the identity object
                let generatedIdentity = GeneratedIdentity(
                    privateIdentity: privateIdentity!,
                    codename: identity.codename,
                    codeset: identity.codeset,
                    pubkey: identity.pubkey
                )

                identities.append(generatedIdentity)

            } catch {
                print(
                    "ERROR: Failed to decode identity JSON: \(error.localizedDescription)"
                )
            }
        }

        return identities
    }

    // Persist a reaction to SwiftData
    private func persistReaction(
        messageIdB64: String,
        emoji: String,
        targetMessageId: String,
        isMe: Bool = true
    ) {
        guard let actor = self.modelActor else {
            print("persistReaction: modelActor not set")
            return
        }
        Task {
            do {
                // Use SwiftDataActor instead of ModelContext
                let reaction = MessageReaction(
                    id: messageIdB64,
                    internalId: InternalIdGenerator.shared.next(),
                    targetMessageId: targetMessageId,
                    emoji: emoji,
                    isMe: isMe
                )
                actor.insert(reaction)
                try actor.save()
            } catch {
                print("persistReaction failed: \(error)")
            }
        }
    }

    // Send a message to a channel by Channel ID (base64-encoded). If tags are provided, they are JSON-encoded and passed along.
    func sendDM(msg: String, channelId: String) {
        guard let cm = channelsManager else {
            fatalError("sendDM(channel): Channels Manager not initialized")
        }
        // Channel IDs are base64 in our storage; attempt base64 decode first, fallback to UTF-8 bytes
        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
            ?? Data()
        do {
            let reportData = try cm.sendMessage(
                channelIdData,
                message: encodeMessage(msg),
                validUntilMS: 0,
                cmixParamsJSON: "".data,
                pingsJSON: nil
            )
            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print(
                        "Channel sendMessage messageID: \(mid.base64EncodedString())"
                    )
                    let chatId = channelId
                    let defaultName: String = {
                        if let actor = self.modelActor {
                            let descriptor = FetchDescriptor<Chat>(
                                predicate: #Predicate { $0.id == chatId }
                            )
                            if let found = try? actor.fetch(descriptor).first {
                                return found.name
                            }
                        }
                        return "Channel \(String(chatId.prefix(8)))"
                    }()

                } else {
                    print("Channel sendMessage returned no messageID")
                }
            } catch {
                print("Failed to decode ChannelSendReport: \(error)")
            }
        } catch {
            print("sendDM(channel) failed: \(error.localizedDescription)")
        }
    }

    // Send a reply to a specific message in a channel
    func sendReply(msg: String, channelId: String, replyToMessageIdB64: String)
    {
        guard let cm = channelsManager else {
            fatalError("sendReply(channel): Channels Manager not initialized")
        }
        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
            ?? Data()
        guard let replyToMessageId = Data(base64Encoded: replyToMessageIdB64)
        else {
            print("sendReply(channel): invalid reply message id base64")
            return
        }
        do {
            let reportData = try cm.sendReply(
                channelIdData,
                message: encodeMessage(msg),
                messageToReactTo: replyToMessageId,
                validUntilMS: 0,
                cmixParamsJSON: "".data,
                pingsJSON: nil
            )
            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print(
                        "Channel sendReply messageID: \(mid.base64EncodedString())"
                    )
                    let chatId = channelId
                    let defaultName: String = {
                        if let actor = self.modelActor {
                            let descriptor = FetchDescriptor<Chat>(
                                predicate: #Predicate { $0.id == chatId }
                            )
                            if let found = try? actor.fetch(descriptor).first {
                                return found.name
                            }
                        }
                        return "Channel \(String(chatId.prefix(8)))"
                    }()

                } else {
                    print("Channel sendReply returned no messageID")
                }
            } catch {
                print("Failed to decode ChannelSendReport (reply): \(error)")
            }
        } catch {
            print("sendReply(channel) failed: \(error.localizedDescription)")
        }
    }

    // Send a reaction to a specific message in a channel
    public func sendReaction(
        emoji: String,
        toMessageIdB64: String,
        inChannelId channelId: String
    ) {
        guard let cm = channelsManager else {
            fatalError(
                "sendReaction(channel): Channels Manager not initialized"
            )
        }
        // Channel IDs are base64 in our storage; attempt base64 decode first, fallback to UTF-8 bytes
        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
            ?? Data()
        guard let targetMessageId = Data(base64Encoded: toMessageIdB64) else {
            print("sendReaction(channel): invalid target message id base64")
            return
        }
        do {
            // Attempt to send the reaction via Channels Manager
            let reportData = try cm.sendReaction(
                channelIdData,
                reaction: emoji,
                messageToReactTo: targetMessageId,
                validUntilMS: Bindings.BindingsValidForeverBindings,
                cmixParamsJSON: "".data,
            )
            // Decode send report with the shared Parser
            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print(
                        "Channel sendReaction messageID: \(mid.base64EncodedString())"
                    )
                } else {
                    print("Channel sendReaction returned no messageID")
                }
                // Persist locally as 'me'
                self.persistReaction(
                    messageIdB64: report.messageID!.base64EncodedString(),
                    emoji: emoji,
                    targetMessageId: toMessageIdB64,
                    isMe: true,
                )
            } catch {
                print("Failed to decode ChannelSendReport (reaction): \(error)")
            }
        } catch {
            print("sendReaction(channel) failed: \(error.localizedDescription)")
        }
    }

    func sendDM(msg: String, toPubKey: Data, partnerToken: Int32) {
        guard let DM else {
            print("ERROR: DM not there")
            fatalError("DM not there")
        }
        do {
            let reportData = try DM.sendText(
                toPubKey,
                partnerToken: partnerToken,
                message: msg,
                leaseTimeMS: 0,
                cmixParamsJSON: "".data
            )

            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print("DM sendText messageID: \(mid.base64EncodedString())")
                    let chatId = toPubKey.base64EncodedString()
                    let defaultName: String = {
                        if let actor = self.modelActor {
                            let descriptor = FetchDescriptor<Chat>(
                                predicate: #Predicate { $0.id == chatId }
                            )
                            if let found = try? actor.fetch(descriptor).first {
                                return found.name
                            }
                        }
                        return "Direct Message"
                    }()

                } else {
                    print("DM sendText returned no messageID")
                }
            } catch {
                print("Failed to decode ChannelSendReport: \(error)")
            }
        } catch let error {
            print("ERROR: Unable to send: " + error.localizedDescription)
        }
    }

    // Send a reply to a specific message in a DM conversation
    func sendReply(
        msg: String,
        toPubKey: Data,
        partnerToken: Int32,
        replyToMessageIdB64: String
    ) {
        guard let DM else {
            print("ERROR: DM not there")
            fatalError("DM not there")
        }
        guard let replyToMessageId = Data(base64Encoded: replyToMessageIdB64)
        else {
            print("sendReply(DM): invalid reply message id base64")
            return
        }
        do {
            let reportData = try DM.sendReply(
                toPubKey,
                partnerToken: partnerToken,
                replyMessage: msg,
                replyToBytes: replyToMessageId,
                leaseTimeMS: 0,
                cmixParamsJSON: "".data
            )
            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print(
                        "DM sendReply messageID: \(mid.base64EncodedString())"
                    )
                    let chatId = toPubKey.base64EncodedString()
                    let defaultName: String = {
                        if let actor = self.modelActor {
                            let descriptor = FetchDescriptor<Chat>(
                                predicate: #Predicate { $0.id == chatId }
                            )
                            if let found = try? actor.fetch(descriptor).first {
                                return found.name
                            }
                        }
                        return "Direct Message"
                    }()

                } else {
                    print("DM sendReply returned no messageID")
                }
            } catch {
                print("Failed to decode ChannelSendReport (DM reply): \(error)")
            }
        } catch let error {
            print("ERROR: Unable to send reply: " + error.localizedDescription)
            fatalError("Unable to send reply: " + error.localizedDescription)
        }
    }

    // Send a reaction to a specific message in a DM conversation
    public func sendReaction(
        emoji: String,
        toMessageIdB64: String,
        toPubKey: Data,
        partnerToken: Int32
    ) {
        guard let DM else {
            print("ERROR: DM not there")
            fatalError("DM not there")
        }
        guard let targetMessageId = Data(base64Encoded: toMessageIdB64) else {
            print("sendReaction(DM): invalid target message id base64")
            return
        }
        do {
            let reportData = try DM.sendReaction(
                toPubKey,
                partnerToken: partnerToken,
                reaction: emoji,
                reactToBytes: targetMessageId,
                cmixParamsJSON: "".data
            )
            // Decode send report with the shared Parser (same as text send)
            do {
                let report = try Parser.decodeChannelSendReport(
                    from: reportData
                )
                if let mid = report.messageID {
                    print(
                        "DM sendReaction messageID: \(mid.base64EncodedString())"
                    )
                } else {
                    print("DM sendReaction returned no messageID")
                }
                // Persist locally as 'me'
                self.persistReaction(
                    messageIdB64: report.messageID!.base64EncodedString(),
                    emoji: emoji,
                    targetMessageId: toMessageIdB64,
                    isMe: true
                )
            } catch {
                print(
                    "Failed to decode ChannelSendReport (DM reaction): \(error)"
                )
            }
        } catch let error {
            print(
                "ERROR: Unable to send reaction: " + error.localizedDescription
            )
            fatalError("Unable to send reaction: " + error.localizedDescription)
        }

    }

    /// Join a channel using a URL (public share link)
    /// - Parameter url: The channel share URL
    /// - Returns: Decoded ChannelJSON containing channel information
    /// - Throws: Error if DecodePublicURL or joinChannel fails
    func joinChannelFromURL(_ url: String) async throws -> ChannelJSON {
        var err: NSError?

        // Decode the URL to get pretty print format
        let prettyPrint = Bindings.BindingsDecodePublicURL(url, &err)

        if let error = err {
            throw error
        }

        // Join using the pretty print format
        return try await joinChannel(prettyPrint)
    }

    /// Join a channel using pretty print format
    /// - Parameter prettyPrint: The channel descriptor in pretty print format
    /// - Returns: Decoded ChannelJSON containing channel information
    /// - Throws: Error if joining fails
    func joinChannel(_ prettyPrint: String) async throws -> ChannelJSON {
        try await Task.sleep(for: .seconds(20))
        guard let cmix else { throw MyError.runtimeError("no net") }
        guard let storageTagListener else {
            print("ERROR: no storageTagListener")
            fatalError("no storageTagListener")
        }
        guard let storageTagEntry = storageTagListener.data else {
            print("ERROR: no storageTagListener data")
            fatalError("no storageTagListener data")
        }
        var err: NSError?
        let cmixId = cmix.getID()
  
        let storageTag = storageTagEntry.utf8

        guard let noti = Bindings.BindingsLoadNotificationsDummy(cmixId, &err)
        else {
            print("ERROR: notifications dummy was nil")
            fatalError("notifications dummy was nil")
        }
        if let e = err {
            throw MyError.runtimeError(
                "could not load notifications dummy: \(e.localizedDescription)"
            )
        }
        print("BindingsLoadChannelsManager: tag - \(storageTag)")
        let cm = Bindings.BindingsLoadChannelsManager(
            cmixId,
            storageTag,
            /* dbFilePath: */ eventModelBuilder,
            /* extensionBuilderIDsJSON: */ nil,
            /* notificationsID: */ noti.getID(),
            /* uiCallbacks: */ channelUICallbacks,
            &err
        )
        if let e = err {
            throw MyError.runtimeError(
                "could not load channels manager: \(e.localizedDescription)"
            )
        }
        guard let cm else {
            throw MyError.runtimeError("channels manager was nil")
        }

        // Retain Channels Manager for channel operations
        self.channelsManager = cm

        // Join the channel and parse the returned JSON
        let raw = try cm.joinChannel(prettyPrint)
        let channel = try Parser.decodeChannel(from: raw)
        print("Joined channel: \(channel.name)")
        return channel
    }

    // downloadNdf uses the mainnet URL to download and verify the
    // network definition file for the xx network.
    // As of this writing, using the xx network is free and using the public
    // network is OK. Check the xx network docs for updates.
    // You can test locally, with the integration or localenvironment
    // repositories with their own ndf files here:
    //  * https://git.xx.network/elixxir/integration
    //  * https://git.xx.network/elixxir/localenvironment
    // integration will run messaging tests against a local network,
    // and localenvironment will run a fixed network local to your machine.
    func downloadNDF(url: String, certFilePath: String) -> Data {
        let certString: String
        do {
            certString = try String(contentsOfFile: certFilePath)
        } catch let error {
            print(
                "ERROR: Missing network certificate, please include a mainnet, testnet,or localnet certificate in the Resources folder: "
                    + error.localizedDescription
            )
            fatalError(
                "Missing network certificate, please include a mainnet, testnet,"
                    + "or localnet certificate in the Resources folder: "
                    + error.localizedDescription
            )
        }

        var err: NSError?
        let ndf = Bindings.BindingsDownloadAndVerifySignedNdfWithUrl(
            url,
            certString,
            &err
        )
        if let err {
            print(
                "ERROR: DownloadAndverifySignedNdfWithUrl(\(url), \(certString)) error: "
                    + err.localizedDescription
            )
            fatalError(
                "DownloadAndverifySignedNdfWithUrl(\(url), \(certString)) error: "
                    + err.localizedDescription
            )
        }
        // Golang functions uss a `return val or nil, nil or err` pattern, so ndf will be valid data after
        // checking if the error has anything in it.
        return ndf!
    }

    // MARK: - Channel URL Utilities

    /// Get the privacy level for a given channel URL
    /// - Parameter url: The channel share URL
    /// - Returns: PrivacyLevel indicating if password is required (secret) or not (public)
    /// - Throws: Error if GetShareUrlType fails
    public func getChannelPrivacyLevel(url: String) throws -> PrivacyLevel {
        var err: NSError?
        var typeValue: Int = 0
        Bindings.BindingsGetShareUrlType(url, &typeValue, &err)

        if let error = err {
            throw error
        }

        return typeValue == 2 ? .secret : .publicChannel
    }

    /// Get channel data from a channel URL
    /// - Parameter url: The channel share URL
    /// - Returns: Decoded ChannelJSON containing channel information
    /// - Throws: Error if DecodePublicURL, GetChannelJSON, or JSON decoding fails
    public func getChannelFromURL(url: String) throws -> ChannelJSON {
        var err: NSError?

        // Step 1: Decode the URL to get pretty print
        let prettyPrint = Bindings.BindingsDecodePublicURL(url, &err)

        if let error = err {
            throw error
        }

        // Step 2: Get channel JSON from pretty print
        guard
            let channelJSONString = Bindings.BindingsGetChannelJSON(
                prettyPrint,
                &err
            )
        else {
            throw err
                ?? NSError(
                    domain: "XXDK",
                    code: -2,
                    userInfo: [
                        NSLocalizedDescriptionKey: "GetChannelJSON returned nil"
                    ]
                )
        }

        if let error = err {
            throw error
        }

        return try Parser.decodeChannel(from: channelJSONString)
    }

    /// Decode a private channel URL with password
    /// - Parameters:
    ///   - url: The private channel share URL
    ///   - password: The password to decrypt the URL
    /// - Returns: Pretty print format of the channel
    /// - Throws: Error if DecodePrivateURL fails
    public func decodePrivateURL(url: String, password: String) throws -> String
    {
        var err: NSError?
        let prettyPrint = Bindings.BindingsDecodePrivateURL(url, password, &err)

        if let error = err {
            throw error
        }

        return prettyPrint
    }

    /// Get channel data from a private channel URL with password
    /// - Parameters:
    ///   - url: The private channel share URL
    ///   - password: The password to decrypt the URL
    /// - Returns: Decoded ChannelJSON containing channel information
    /// - Throws: Error if DecodePrivateURL, GetChannelJSON, or JSON decoding fails
    public func getPrivateChannelFromURL(url: String, password: String) throws
        -> ChannelJSON
    {
        var err: NSError?

        // Step 1: Decode the private URL with password to get pretty print
        let prettyPrint = try decodePrivateURL(url: url, password: password)

        // Step 2: Get channel JSON from pretty print
        guard
            let channelJSONString = Bindings.BindingsGetChannelJSON(
                prettyPrint,
                &err
            )
        else {
            throw err
                ?? NSError(
                    domain: "XXDK",
                    code: -2,
                    userInfo: [
                        NSLocalizedDescriptionKey: "GetChannelJSON returned nil"
                    ]
                )
        }

        if let error = err {
            throw error
        }

        return try Parser.decodeChannel(from: channelJSONString)
    }

    /// Enable direct messages for a channel
    /// - Parameter channelId: The channel ID (base64-encoded)
    /// - Throws: Error if EnableDirectMessages fails or channels manager is not initialized
    public func enableDirectMessages(channelId: String) throws {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }

        // Channel IDs are base64 in our storage; attempt base64 decode first, fallback to UTF-8 bytes
        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
            ?? Data()

        do {
            try cm.enableDirectMessages(channelIdData)
        } catch {
            fatalError("failed to enable direct messages \(error)")
        }

        print("Successfully enabled direct messages for channel: \(channelId)")
    }

    /// Disable direct messages for a channel
    /// - Parameter channelId: The channel ID (base64-encoded)
    /// - Throws: Error if DisableDirectMessages fails or channels manager is not initialized
    public func disableDirectMessages(channelId: String) throws {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }

        // Channel IDs are base64 in our storage; attempt base64 decode first, fallback to UTF-8 bytes
        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
            ?? Data()

        do {
            try cm.disableDirectMessages(channelIdData)
        } catch {
            fatalError("failed to disable direct messages \(error)")
        }

        print("Successfully disabled direct messages for channel: \(channelId)")
    }

    /// Check if direct messages are enabled for a channel
    /// - Parameter channelId: The channel ID (base64-encoded)
    /// - Returns: True if DMs are enabled, false otherwise
    /// - Throws: Error if AreDMsEnabled fails or channels manager is not initialized
    public func areDMsEnabled(channelId: String) throws -> Bool {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }

        // Channel IDs are base64 in our storage; attempt base64 decode first, fallback to UTF-8 bytes
        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
            ?? Data()

        var result = ObjCBool(false)

        try cm.areDMsEnabled(channelIdData, ret0_: &result)

        return result.boolValue
    }

    /// Leave a channel
    /// - Parameter channelId: The channel ID (base64-encoded)
    /// - Throws: Error if LeaveChannel fails or channels manager is not initialized
    public func leaveChannel(channelId: String) throws {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }

        // Channel IDs are base64 in our storage; attempt base64 decode first, fallback to UTF-8 bytes
        let channelIdData =
            Data(base64Encoded: channelId) ?? channelId.data(using: .utf8)
            ?? Data()

        do {
            try cm.leaveChannel(channelIdData)
        } catch {
            fatalError("failed to leave channel \(error)")
        }

        print("Successfully left channel: \(channelId)")
    }
    
    /// Create a new channel
    public func createChannel(name: String, description: String, privacyLevel: PrivacyLevel, enableDms: Bool) async throws -> ChannelJSON {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }
        var err: NSError?
        let channelDataString = cm.generateChannel(name, description: description, privacyLevel: privacyLevel == .secret ? 2 : 0, error: &err)
        if let error = err {
            throw error
        }
        guard let channelData = channelDataString.data(using: .utf8) else {
            throw MyError.runtimeError("Failed to encode channel data")
        }
        return try Parser.decodeChannel(from: channelData)
    }
    
    /// Get share URL for a channel
    public func getShareURL(channelId: String, host: String) throws -> String? {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }
        
        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()
        let urlData = try cm.getShareURL(0, host: host, maxUses: 0, channelIdBytes: channelIdData)
        return urlData.utf8
    }
    
    /// Check if user is admin of a channel
    public func isChannelAdmin(channelId: String) -> Bool {
        guard let cm = channelsManager else { return false }
        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()
        var result = ObjCBool(false)
        try? cm.isChannelAdmin(channelIdData, ret0_: &result)
        return result.boolValue
    }
    
    /// Export channel admin key
    public func exportChannelAdminKey(channelId: String, encryptionPassword: String) throws -> String {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }
        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()
        let keyData = try cm.exportChannelAdminKey(channelIdData, encryptionPassword: encryptionPassword)
        return keyData.base64EncodedString()
    }
    
    /// Import channel admin key
    public func importChannelAdminKey(channelId: String, encryptionPassword: String, privateKey: String) throws {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }
        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()
        guard let privateKeyData = Data(base64Encoded: privateKey) else {
            throw MyError.runtimeError("Invalid private key encoding")
        }
        try cm.importChannelAdminKey(channelIdData, encryptionPassword: encryptionPassword, encryptedPrivKey: privateKeyData)
    }
    
    /// Export identity with password encryption
    public func exportIdentity(password: String) throws -> Data {
        guard let cmix = cmix else {
            throw MyError.runtimeError("cMix not initialized")
        }
        return try cmix.ekvGet("MyPrivateIdentity")
    }
    
    /// Import identity from encrypted data
    public func importIdentity(password: String, data: Data) throws -> Data {
        var err: NSError?
        guard let identity = Bindings.BindingsImportPrivateIdentity(password, data, &err) else {
            throw err ?? MyError.runtimeError("Failed to import identity")
        }
        if let error = err {
            throw error
        }
        return identity
    }
    
    /// Delete a message from a channel
    public func deleteMessage(channelId: String, messageId: String) {
        guard let cm = channelsManager else {
            print("deleteMessage: Channels Manager not initialized")
            return
        }
        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()
        guard let messageIdData = Data(base64Encoded: messageId) else {
            print("deleteMessage: invalid message id base64")
            return
        }
        do {
            try cm.deleteMessage(channelIdData, targetMessageIdBytes: messageIdData, cmixParamsJSON: Data())
            print("Successfully deleted message: \(messageId)")
        } catch {
            print("deleteMessage failed: \(error)")
        }
    }
    
    /// Logout and clear state
    public func logout() async {
        // Stop network follower if running
        try? cmix?.stopNetworkFollower()
        
        // Clear references
        channelsManager = nil
        channelsFileTransfer = nil
        e2e = nil
        DM = nil
        
        // Clear downloaded NDF to force re-download
        downloadedNdf = nil
        
        await MainActor.run {
            codename = nil
            codeset = 0
            status = "..."
            statusPercentage = 0
        }
    }
    
    /// Get muted users for a channel
    public func getMutedUsers(channelId: String) throws -> [Data] {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }
        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()
        let mutedData = try cm.getMutedUsers(channelIdData)
        
        // Parse the JSON array of muted user public keys
        guard let jsonArray = try? JSONSerialization.jsonObject(with: mutedData) as? [[String: Any]] else {
            return []
        }
        
        return jsonArray.compactMap { dict -> Data? in
            guard let pubkeyB64 = dict["pubkey"] as? String else { return nil }
            return Data(base64Encoded: pubkeyB64)
        }
    }
    
    /// Mute or unmute a user in a channel
    public func muteUser(channelId: String, pubKey: Data, mute: Bool) throws {
        guard let cm = channelsManager else {
            throw MyError.runtimeError("Channels Manager not initialized")
        }
        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()
        try cm.muteUser(channelIdData, mutedUserPubKeyBytes: pubKey, undoAction: !mute, validUntilMS: 0, cmixParamsJSON: Data())
    }
    
    /// Check if current user is muted in a channel
    public func isMuted(channelId: String) -> Bool {
        // Check if user is in the muted users list
        guard let mutedUsers = try? getMutedUsers(channelId: channelId),
              let myPubKey = DM?.getPublicKey() else {
            return false
        }
        return mutedUsers.contains(myPubKey)
    }
    
    // MARK: - File Transfer API
    
    // E2e object for file transfer
    private var e2e: BindingsE2e?
    
    // File transfer manager for channels
    private var channelsFileTransfer: ChannelsFileTransfer?
    
    /// Initialize channels file transfer
    public func initChannelsFileTransfer(paramsJson: Data? = nil) throws {
        print("[FT] initChannelsFileTransfer called")
        // File transfer should already be initialized, just verify
        guard channelsFileTransfer != nil else {
            print("[FT] ERROR: File transfer not initialized")
            throw MyError.runtimeError("File transfer not available")
        }
    }
    
    /// Upload a file
    public func uploadFile(
        fileData: Data,
        retry: Float,
        progressCB: FtSentProgressCallback,
        periodMS: Int
    ) throws -> Data {
        print("[FT] uploadFile called - size: \(fileData.count) bytes")
        guard let ft = channelsFileTransfer else {
            print("[FT] ERROR: File transfer not initialized")
            throw MyError.runtimeError("File transfer not initialized")
        }
        return try ft.upload(fileData: fileData, retry: retry, progressCB: progressCB, periodMS: periodMS)
    }
    
    /// Send a file to a channel
    public func sendFile(
        channelId: String,
        fileLinkJSON: Data,
        fileName: String,
        fileType: String,
        preview: Data?,
        validUntilMS: Int = 0
    ) throws -> ChannelSendReportJSON {
        guard let ft = channelsFileTransfer else {
            throw MyError.runtimeError("File transfer not initialized")
        }
        
        let channelIdData = Data(base64Encoded: channelId) ?? channelId.data(using: .utf8) ?? Data()
        
        let reportData = try ft.send(
            channelIdBytes: channelIdData,
            fileLinkJSON: fileLinkJSON,
            fileName: fileName,
            fileType: fileType,
            preview: preview,
            validUntilMS: validUntilMS,
            cmixParamsJSON: nil,
            pingsJSON: nil
        )
        
        return try Parser.decodeChannelSendReport(from: reportData)
    }
    
    /// Retry a failed file upload
    public func retryFileUpload(
        fileIDBytes: Data,
        progressCB: FtSentProgressCallback,
        periodMS: Int = 500
    ) throws {
        guard let ft = channelsFileTransfer else {
            throw MyError.runtimeError("File transfer not initialized")
        }
        try ft.retryUpload(fileIDBytes: fileIDBytes, progressCB: progressCB, periodMS: periodMS)
    }
    
    /// Close a file send operation
    public func closeFileSend(fileIDBytes: Data) throws {
        guard let ft = channelsFileTransfer else {
            throw MyError.runtimeError("File transfer not initialized")
        }
        try ft.closeSend(fileIDBytes: fileIDBytes)
    }
    
    /// Register a progress callback for file upload
    public func registerFileProgressCallback(
        fileIDBytes: Data,
        progressCB: FtSentProgressCallback,
        periodMS: Int = 500
    ) throws {
        guard let ft = channelsFileTransfer else {
            throw MyError.runtimeError("File transfer not initialized")
        }
        try ft.registerSentProgressCallback(fileIDBytes: fileIDBytes, progressCB: progressCB, periodMS: periodMS)
    }
    
    /// Download a file from a received file message
    public func downloadFile(
        fileInfoJSON: Data,
        progressCB: FtReceivedProgressCallback,
        periodMS: Int = 500
    ) throws -> Data {
        guard let ft = channelsFileTransfer else {
            throw MyError.runtimeError("File transfer not initialized")
        }
        print("[FT] downloadFile called - fileInfoJSON: \(fileInfoJSON.count) bytes")
        return try ft.download(fileInfoJSON: fileInfoJSON, progressCB: progressCB, periodMS: periodMS)
    }
}


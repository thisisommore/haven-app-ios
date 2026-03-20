import Bindings
import SQLiteData
import SwiftUI
import UniformTypeIdentifiers

enum HomeSheet: Identifiable {
  case newChat
  case createSpace
  case exportIdentity
  case qrScanner
  case nicknamePicker
  case qrCode(QRData)

  var id: String {
    switch self {
    case .newChat: return "newChat"
    case .createSpace: return "createSpace"
    case .exportIdentity: return "exportIdentity"
    case .qrScanner: return "qrScanner"
    case .nicknamePicker: return "nicknamePicker"
    case .qrCode: return "qrCode"
    }
  }
}

struct HomeView<T: XXDKP>: View {
  @State private var activeSheet: HomeSheet?
  @State private var toastMessage: String?
  @State private var showLogoutAlert = false
  @State private var currentNickname: String?
  @State private var searchText: String = ""
  @State private var isLoggingOut = false
  @State private var didNormalizeNavigation = false
  @FetchAll(ChatModel.order { $0.name }) private var chats: [ChatModel]

  @EnvironmentObject var xxdk: T
  @State private var didStartLoad = false
  @Dependency(\.defaultDatabase) var database
  @EnvironmentObject private var appStorage: AppStorage
  @EnvironmentObject private var navigation: AppNavigationPath
  @Environment(\.isSplitView) private var isSplitView
  @EnvironmentObject private var selectedChat: SelectedChat

  @State private var showTooltip = false

  private var filteredChats: [ChatModel] {
    if self.searchText.isEmpty {
      return self.chats
    }
    return self.chats.filter { chat in
      // Search by chat name (use "Notes" for self chat)
      let displayName = chat.name == "<self>" ? "Notes" : chat.name
      if displayName.localizedCaseInsensitiveContains(self.searchText) {
        return true
      }
      if let senderId =
        (try? database.read({ db in
          try ChatMessageModel.where {
            $0.chatId.eq(chat.id) && $0.isIncoming && $0.senderId != nil
          }.limit(1).fetchOne(db)?.senderId
        })).flatMap({ $0 }),
        let nickname = try? database.read({ db in
          try MessageSenderModel.where { $0.id.eq(senderId) }.fetchOne(db)?.nickname
        }),
        !nickname.isEmpty,
        nickname.localizedCaseInsensitiveContains(searchText) {
        return true
      }
      return false
    }
  }

  var body: some View {
    let chatList = List(selection: $selectedChat.chatId) {
      ForEach(self.filteredChats) { chat in
        ChatRowView<T>(chat: chat)
          .tag(chat.id)
      }
    }
    .scrollContentBackground(.hidden)
    .background(Color.appBackground)
    .onChange(of: self.selectedChat.chatId) { _, newValue in
      if let chatId = newValue,
         let chat = chats.first(where: { $0.id == chatId }) {
        self.selectedChat.chatTitle = chat.name
      }
    }

    let listHeader =
      chatList
        .searchable(
          text: self.$searchText,
          placement: .navigationBarDrawer(displayMode: .automatic),
          prompt: "Search chats"
        )
        .tint(.gray.opacity(0.3))
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 12) {
              UserMenuButton(
                codename: self.xxdk.codename,
                nickname: self.currentNickname,
                onNicknameTap: {
                  self.activeSheet = .nicknamePicker
                },
                onExport: {
                  self.activeSheet = .exportIdentity
                },
                onShareQR: {
                  guard let dm = xxdk.dm,
                        let pubKey = dm.getPublicKey(),
                        !pubKey.isEmpty
                  else {
                    return
                  }
                  self.activeSheet = .qrCode(
                    QRData(
                      token: dm.getToken(), pubKey: pubKey, codeset: self.xxdk.codeset
                    )
                  )
                },
                onLogout: {
                  self.showLogoutAlert = true
                }
              )
              .frame(width: 28, height: 28)

              if self.xxdk.statusPercentage != 100 {
                Button(action: {
                  self.showTooltip.toggle()
                }) {
                  ProgressView().tint(.haven)
                }
              }
            }
          }.hiddenSharedBackground()

          ToolbarItem(placement: .topBarTrailing) {
            PlusMenuButton(
              onJoinChannel: { self.activeSheet = .newChat },
              onCreateSpace: { self.activeSheet = .createSpace },
              onScanQR: { self.activeSheet = .qrScanner }
            )
            .frame(width: 28, height: 28)
          }.hiddenSharedBackground()
        }

    let withSheet =
      listHeader
        .sheet(item: self.$activeSheet) { sheet in
          switch sheet {
          case .newChat:
            NewChatView<T>()
          case .createSpace:
            CreateSpaceView<T>()
          case let .qrCode(data):
            QRCodeView(dmToken: data.token, pubKey: data.pubKey, codeset: data.codeset)
          case .qrScanner:
            QRScannerView(
              onCodeScanned: { code in
                self.handleAddUser(code: code)
              },
              onShowMyQR: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                  guard let dm = xxdk.dm, let pubKey = dm.getPublicKey()
                  else {
                    return
                  }
                  self.activeSheet = .qrCode(
                    QRData(
                      token: dm.getToken(), pubKey: pubKey, codeset: self.xxdk.codeset
                    )
                  )
                }
              }
            )
          case .nicknamePicker:
            NicknamePickerView<T>(codename: self.xxdk.codename ?? "")
              .onDisappear {
                self.loadCurrentNickname()
              }
          case .exportIdentity:
            if let codename = xxdk.codename {
              ExportIdentitySheet(
                xxdk: self.xxdk,
                onSuccess: { message in
                  withAnimation(.spring(response: 0.3)) {
                    self.toastMessage = message
                  }
                  DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                      self.toastMessage = nil
                    }
                  }
                },
                codename: codename
              )
            }
          }
        }
        .alert("Logout", isPresented: self.$showLogoutAlert) {
          Button("Cancel", role: .cancel) {}
          Button("Logout", role: .destructive) {
            self.isLoggingOut = true
            Task {
              try! await self.xxdk.logout()

              try! await self.database.write { db in
                try ChatMessageModel.delete().execute(db)
                try MessageReactionModel.delete().execute(db)
                try MessageSenderModel.delete().execute(db)
                try ChatModel.delete().execute(db)
              }

              self.appStorage.clearAll()
              await MainActor.run {
                self.navigation.path = NavigationPath()
                self.navigation.path.append(Destination.password)
              }
            }
          }
        } message: {
          Text(
            "If you haven't backed up your identity, you will lose access to it permanently. Are you sure you want to logout?"
          )
        }

    return
      withSheet
        .overlay {
          if let toastMessage {
            VStack {
              Spacer()
              HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.white)
                Text(toastMessage)
                  .font(.subheadline)
                  .fontWeight(.medium)
                  .foregroundColor(.white)
              }
              .padding(.horizontal, 20)
              .padding(.vertical, 14)
              .background(Color.haven)
              .cornerRadius(25)
              .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
              .padding(.bottom, 50)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
          }
        }
        .overlay {
          if self.isLoggingOut {
            ZStack {
              Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {} // Block taps

              VStack(spacing: 16) {
                ProgressView()
                  .controlSize(.large)
                  .tint(.white)

                Text(self.xxdk.status)
                  .font(.headline)
                  .foregroundStyle(.white)
              }
              .padding(30)
              .background(.ultraThinMaterial)
              .cornerRadius(16)
            }
          }
        }
        .background(Color.appBackground)
        .onAppear {
          if !self.didNormalizeNavigation {
            self.didNormalizeNavigation = true
            if !self.navigation.path.isEmpty {
              self.navigation.path = NavigationPath()
            }
          }
          if self.xxdk.statusPercentage == 0 && !self.didStartLoad {
            self.didStartLoad = true
            Task.detached {
              await self.xxdk.loadCmix()
              let privateIdentity = try! self.xxdk.loadSavedPrivateIdentity()
              await self.xxdk.loadClients(privateIdentity: privateIdentity)
              await self.xxdk.startNetworkFollower()
            }
          }
          self.loadCurrentNickname()
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.large)
  }

  private func handleAddUser(code: String) {
    guard let url = URL(string: code),
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else {
      return
    }

    guard components.scheme == "haven",
          components.host == "dm",
          let queryItems = components.queryItems
    else {
      return
    }

    guard let tokenStr = queryItems.first(where: { $0.name == "token" })?.value,
          let token64 = Int64(tokenStr),
          let pubKeyStr = queryItems.first(where: { $0.name == "pubKey" })?.value,
          let pubKey = Data(base64Encoded: pubKeyStr)
    else {
      return
    }

    // Convert Int64 token to Int32 (handling unsigned 32-bit values that overflow signed Int32)
    let token = Int32(bitPattern: UInt32(truncatingIfNeeded: token64))

    // Get codeset from URL
    guard let codesetStr = queryItems.first(where: { $0.name == "codeset" })?.value,
          let codeset = Int(codesetStr)
    else {
      withAnimation(.spring(response: 0.3)) {
        self.toastMessage = "Invalid QR code: missing codeset"
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        withAnimation { self.toastMessage = nil }
      }
      return
    }

    // Derive codename and color using BindingsConstructIdentity
    let identity: IdentityJSON?
    do {
      identity = try BindingsStatic.constructIdentity(pubKey: pubKey, codeset: codeset)
    } catch {
      AppLogger.home.error(
        "BindingsConstructIdentity failed: \(error.localizedDescription, privacy: .public)"
      )
      withAnimation(.spring(response: 0.3)) {
        self.toastMessage = "Failed to derive identity"
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        withAnimation { self.toastMessage = nil }
      }
      return
    }
    guard let identity
    else {
      AppLogger.home.error("BindingsConstructIdentity returned nil")
      withAnimation(.spring(response: 0.3)) { self.toastMessage = "Failed to derive identity" }
      DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        withAnimation { self.toastMessage = nil }
      }
      return
    }

    let name: String
    let color: Int
    name = identity.Codename
    var colorStr = identity.Color
    if colorStr.hasPrefix("0x") || colorStr.hasPrefix("0X") {
      colorStr.removeFirst(2)
    }
    color = Int(colorStr, radix: 16) ?? 0xE97451

    let newChat = ChatModel(pubKey: pubKey, name: name, dmToken: token, color: color)

    Task.detached {
      try? self.database.write { db in
        try ChatModel.insert { newChat }.execute(db)
      }
    }

    withAnimation(.spring(response: 0.3)) {
      self.toastMessage = "User added successfully"
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      withAnimation {
        self.toastMessage = nil
      }
    }
  }

  private func loadCurrentNickname() {
    do {
      if let nickname = try xxdk.dm?.getNickname() {
        self.currentNickname = nickname.isEmpty ? nil : nickname
      } else {
        self.currentNickname = nil
      }
    } catch {
      self.currentNickname = nil
    }
  }
}

#Preview {
  HomeView<XXDKMock>()
    .mock()
}

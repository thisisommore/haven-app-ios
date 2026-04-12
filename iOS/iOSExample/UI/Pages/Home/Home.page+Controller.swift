import Bindings
import Observation
import SQLiteData
import SwiftUI

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

@MainActor
@Observable
final class HomePageController {
  var activeSheet: HomeSheet?
  var toastMessage: String?
  var showLogoutAlert = false
  var currentNickname: String?
  var searchText: String = ""
  var isLoggingOut = false
  var didNormalizeNavigation = false
  var didStartLoad = false
  var showTooltip = false

  @ObservationIgnored
  @FetchAll(ChatModel.order { $0.name }) private var chats: [ChatModel]

  @ObservationIgnored
  @Dependency(\.defaultDatabase) var database
  @ObservationIgnored
  @Dependency(\.appStorage) var appStorage

  var filteredChats: [ChatModel] {
    self.filteredChats(from: self.chats)
  }

  func filteredChats(from chats: [ChatModel]) -> [ChatModel] {
    if self.searchText.isEmpty {
      return chats
    }
    let searchText = self.searchText
    return chats.filter { chat in
      let displayName = chat.name == "ChatModel.selfChatInternalName" ? "Notes" : chat.name
      return displayName.localizedCaseInsensitiveContains(searchText)
    }
  }

  func handleAddUser(code: String) {
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

    let token = Int32(bitPattern: UInt32(truncatingIfNeeded: token64))

    guard let codesetStr = queryItems.first(where: { $0.name == "codeset" })?.value,
          let codeset = Int(codesetStr)
    else {
      self.showToast("Invalid QR code: missing codeset")
      return
    }

    let identity: IdentityJSON?
    do {
      identity = try BindingsStatic.constructIdentity(pubKey: pubKey, codeset: codeset)
    } catch {
      AppLogger.home.error(
        "BindingsConstructIdentity failed: \(error.localizedDescription, privacy: .public)"
      )
      self.showToast("Failed to derive identity")
      return
    }
    guard let identity
    else {
      AppLogger.home.error("BindingsConstructIdentity returned nil")
      self.showToast("Failed to derive identity")
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

    try? self.database.write { db in
      try ChatModel.insert { newChat }.execute(db)
    }

    self.showToast("User added successfully", dismissAfter: 2)
  }

  func loadCurrentNickname<T: XXDKP>(xxdk: T) {
    if let nickname = try? xxdk.dm.getNickname() {
      self.currentNickname = nickname.isEmpty ? nil : nickname
    } else {
      self.currentNickname = nil
    }
  }

  func openShareQRCode<T: XXDKP>(xxdk: T) {
    guard
      let pubKey = xxdk.dm.getPublicKey(),
      !pubKey.isEmpty
    else {
      return
    }
    self.activeSheet = .qrCode(
      QRData(
        token: xxdk.dm.getToken(), pubKey: pubKey, codeset: xxdk.codeset
      )
    )
  }

  func scheduleShowMyQRAfterScannerDismissal<T: XXDKP>(xxdk: T) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      self.openShareQRCode(xxdk: xxdk)
    }
  }

  func onExportSuccess(message: String) {
    self.showToast(message, dismissAfter: 2)
  }

  func performLogout<T: XXDKP>(
    xxdk: T,
    navigation: AppNavigationPath
  ) {
    self.isLoggingOut = true
    Task {
      try! await xxdk.logout()

      try! await self.database.write { db in
        try ChatMessageModel.delete().execute(db)
        try MessageReactionModel.delete().execute(db)
        try MessageSenderModel.delete().execute(db)
        try ChatModel.delete().execute(db)
      }

      self.appStorage.clearAll()
      await MainActor.run {
        navigation.path = NavigationPath()
        navigation.path.append(Destination.password)
      }
    }
  }

  func onAppear<T: XXDKP>(navigation: AppNavigationPath, xxdk: T) {
    if !self.didNormalizeNavigation {
      self.didNormalizeNavigation = true
      if !navigation.path.isEmpty {
        navigation.path = NavigationPath()
      }
    }
    if xxdk.statusPercentage == 0, !self.didStartLoad {
      self.didStartLoad = true
      Task.detached {
        await xxdk.loadCmix()
        let privateIdentity = try! xxdk.loadSavedPrivateIdentity()
        await xxdk.loadClients(privateIdentity: privateIdentity)
        await xxdk.startNetworkFollower()
      }
    }
    if xxdk.statusPercentage == 100 {
      self.loadCurrentNickname(xxdk: xxdk)
    }
  }

  private func showToast(_ message: String, dismissAfter seconds: TimeInterval = 3) {
    withAnimation(.spring(response: 0.3)) {
      self.toastMessage = message
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
      withAnimation { self.toastMessage = nil }
    }
  }
}

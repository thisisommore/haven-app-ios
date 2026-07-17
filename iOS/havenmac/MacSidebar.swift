//
//  MacSidebar.swift
//  haven
//
//  Chat list sidebar: search, conversation rows, and the toolbar menus for
//  creating/joining chats and account actions.
//

import SwiftUI

struct MacSidebar: View {
  @State private var controller = HomePageController()

  @EnvironmentObject private var xxdk: XXDK
  @EnvironmentObject private var navigation: AppNavigationPath
  @EnvironmentObject private var selectedChat: SelectedChat

  var body: some View {
    List(selection: self.$selectedChat.chatId) {
      ForEach(self.controller.filteredChats) { chat in
        ChatRowView<XXDK>(chat: chat)
          .tag(chat.id)
      }
    }
    .searchable(text: self.$controller.searchText, placement: .sidebar, prompt: "Search chats")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Menu {
          Button("Join Channel…") { self.controller.activeSheet = .newChat }
          Button("Create Space…") { self.controller.activeSheet = .createSpace }
        } label: {
          Image(systemName: "plus")
        }
        .menuStyle(.borderlessButton)
        .help("New chat")
      }

      ToolbarItem(placement: .navigation) {
        Menu {
          if let nickname = controller.currentNickname {
            Text(nickname)
          }
          Button("My QR Code…") { self.controller.openShareQRCode(xxdk: self.xxdk) }
          Button("Nickname…") { self.controller.activeSheet = .nicknamePicker }
          Button("Export Identity…") { self.controller.activeSheet = .exportIdentity }
          Divider()
          Button("Log Out…", role: .destructive) { self.controller.showLogoutAlert = true }
        } label: {
          Image(systemName: "person.circle")
        }
        .menuStyle(.borderlessButton)
        .help("Account")
      }
    }
    .sheet(item: self.$controller.activeSheet) { sheet in
      switch sheet {
      case .newChat:
        NewChatSheet<XXDK>()
          .frame(minWidth: 460, minHeight: 420)
      case .createSpace:
        CreateSpaceSheet<XXDK>()
          .frame(minWidth: 460, minHeight: 420)
      case let .qrCode(data):
        MacQRCodeSheet(data: data)
      case .nicknamePicker:
        MacNicknameSheet<XXDK>()
      case .exportIdentity:
        MacExportIdentitySheet<XXDK>()
      case .qrScanner:
        // Camera scanning is iOS-only; unreachable from the mac UI.
        EmptyView()
      }
    }
    .overlay(alignment: .bottom) {
      if let toast = controller.toastMessage {
        Text(toast)
          .font(.callout)
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(.regularMaterial, in: Capsule())
          .padding(.bottom, 12)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .overlay {
      if self.controller.isLoggingOut {
        ZStack {
          Color.black.opacity(0.35).ignoresSafeArea()
          VStack(spacing: 12) {
            ProgressView()
            Text(self.xxdk.status.message)
              .font(.callout)
              .foregroundStyle(.secondary)
          }
          .padding(24)
          .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
      } else if self.controller.isLoading {
        ProgressView()
          .controlSize(.small)
      }
    }
    .alert(
      "Log out of Haven?",
      isPresented: self.$controller.showLogoutAlert
    ) {
      Button("Log Out", role: .destructive) {
        self.controller.performLogout(xxdk: self.xxdk, navigation: self.navigation)
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This deletes your identity and all local messages from this Mac.")
    }
    .onAppear {
      self.controller.onAppear(navigation: self.navigation, xxdk: self.xxdk)
    }
  }
}

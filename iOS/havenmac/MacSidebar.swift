//
//  MacSidebar.swift
//  haven
//
//  Chat list sidebar: search, conversation rows, and the toolbar menus for
//  creating/joining chats and account actions.
//

import SwiftUI
import AppKit

struct MacSidebar: View {
  @State private var controller = HomePageController()

  @EnvironmentObject private var xxdk: XXDK
  @EnvironmentObject private var navigation: AppNavigationPath
  @EnvironmentObject private var selectedChat: SelectedChat

  @State private var showNewChatMenu = false

  var body: some View {
    List(selection: self.$selectedChat.chatId) {
      ForEach(self.controller.filteredChats) { chat in
        ChatRowView<XXDK>(chat: chat)
          .tag(chat.id)
      }
    }
    // Neutralize the accent-colored selection/press highlight in the sidebar;
    // rows render with the native gray selection instead.
    .tint(Color(nsColor: .unemphasizedSelectedContentBackgroundColor))
    .searchable(text: self.$controller.searchText, placement: .sidebar, prompt: "Search chats")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          self.showNewChatMenu.toggle()
        } label: {
          Image(systemName: "plus")
        }
        .help("New chat")
        .popover(isPresented: self.$showNewChatMenu, arrowEdge: .bottom) {
          VStack(alignment: .leading, spacing: 2) {
            Button {
              self.showNewChatMenu = false
              self.controller.activeSheet = .newChat
            } label: {
              Text("Join Channel…")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)

            Button {
              self.showNewChatMenu = false
              self.controller.activeSheet = .createSpace
            } label: {
              Text("Create Space…")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
          }
          .padding(4)
          .frame(width: 180)
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      MacAccountChip<XXDK>(controller: self.controller)
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

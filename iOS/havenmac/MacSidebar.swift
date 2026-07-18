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
    // Selection is handled manually instead of `List(selection:)` because the
    // system selection highlight always flashes the app accent color (orange)
    // while the mouse is pressed and cannot be overridden with `.tint`.
    // Rows draw their own neutral gray background when selected.
    List {
      ForEach(self.controller.filteredChats) { chat in
        ChatRowView<XXDK>(chat: chat)
          .contentShape(Rectangle())
          .onTapGesture {
            self.selectedChat.chatId = chat.id
          }
          .listRowBackground(
            self.selectedChat.chatId == chat.id
              ? Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
              : Color.clear
          )
      }
    }
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
      Group {
        switch sheet {
        case .newChat:
          MacJoinChannelView<XXDK>()
        case .createSpace:
          MacCreateSpaceView<XXDK>()
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
      .dismissOnOutsideClick()
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

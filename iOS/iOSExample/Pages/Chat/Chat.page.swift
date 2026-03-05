//
//  Chat.page.swift
//  iOSExample
//
//  Created by Om More on 22/09/25.
//

import SwiftUI

struct ChatView<T: XXDKP>: View {
  let chatId: String
  let chatTitle: String

  @EnvironmentObject var selectedChat: SelectedChat
  @EnvironmentObject var chatStore: ChatStore
  @EnvironmentObject var xxdk: T
  @State private var chat: ChatModel?

  private var isChannel: Bool {
    guard let chat else { return false }
    return chat.name != "<self>" && chat.dmToken == nil
  }

  @Environment(\.dismiss) private var dismiss
  @State private var replyingTo: ChatMessageModel? = nil
  @State private var replyingToSenderName: String? = nil
  @State private var showChannelOptions: Bool = false
  @State private var isAdmin: Bool = false
  @State private var isMuted: Bool = false

  private func markMessagesAsRead() {
    guard chat != nil else { return }
    try? chatStore.markMessagesAsRead(chatId: chatId)
    chat = try? chatStore.fetchChat(id: chatId)
  }

  init(chatId: String, chatTitle: String) {
    self.chatId = chatId
    self.chatTitle = chatTitle
  }

  private func refreshMuteState() {
    guard isChannel else {
      isMuted = false
      return
    }
    isMuted = xxdk.isMuted(channelId: chatId)
  }

  var body: some View {
    MaxChat(chatId: chatId)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .safeAreaInset(edge: .bottom) {
      if isMuted {
        HStack {
          Image(systemName: "speaker.slash.fill")
            .foregroundColor(.secondary)
          Text("You are muted in this channel")
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
      } else {
        MessageForm<T>(
          chat: chat,
          replyTo: replyingTo,
          replyToSenderName: replyingToSenderName,
          onCancelReply: {
            replyingTo = nil
            replyingToSenderName = nil
          }
        )
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(true)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          if selectedChat.chatId == chatId {
            selectedChat.clear()
          } else {
            dismiss()
          }
        } label: {
          HStack(spacing: 2) {
            Image(systemName: "chevron.left")
            Text("Back")
          }
          .font(.headline)
          .foregroundStyle(.haven)
        }
      }
      ToolbarItem(placement: .principal) {
        Button {
          showChannelOptions = true
        } label: {
          HStack(spacing: 4) {
            Text(chatTitle == "<self>" ? "Notes" : chatTitle)
              .font(.headline.weight(.semibold))
              .foregroundStyle(.primary)
            if isChannel && chat?.isSecret == true {
              SecretBadge()
            }
            if isChannel && isAdmin {
              AdminBadge()
            }
          }
        }
      }
    }
    .sheet(isPresented: $showChannelOptions) {
      ChannelOptionsView<T>(chat: chat) {
        Task {
          do {
            try xxdk.leaveChannel(channelId: chatId)
            try chatStore.deleteChat(id: chatId)
            await MainActor.run {
              dismiss()
            }
          } catch {
            AppLogger.channels.error(
              "Failed to leave channel: \(error.localizedDescription, privacy: .public)")
          }
        }
      }
      .environmentObject(xxdk)
    }
    .onAppear {
      chat = try? chatStore.fetchChat(id: chatId)
      isAdmin = chat?.isAdmin ?? false
      refreshMuteState()
      markMessagesAsRead()
    }
    .onReceive(NotificationCenter.default.publisher(for: .userMuteStatusChanged)) { notification in
      if let channelID = notification.userInfo?["channelID"] as? String,
        channelID == chatId
      {
        refreshMuteState()
      }
    }
    .id("chat-\(chatId)")
    .onChange(of: showChannelOptions) { _, newValue in
      if !newValue {
        chat = try? chatStore.fetchChat(id: chatId)
        isAdmin = chat?.isAdmin ?? false
      }
    }
    .background(ChatBackgroundView())
  }
}

#Preview {
  ChatView<XXDKMock>(
    chatId: previewChatId,
    chatTitle: "Mayur"
  )
  .mock()
}

//
//  MacChannelOptionsView.swift
//  haven
//
//  Channel options dialog redesigned for macOS: grouped settings-style form,
//  native controls, and a standard button bar. Uses the shared
//  ChannelOptionsController for all logic.
//

import SQLiteData
import SwiftUI

struct MacChannelOptionsView<T: XXDKP>: View {
  @State private var controller = ChannelOptionsController()

  let chat: ChatModel
  let onLeaveChannel: () -> Void

  @EnvironmentObject private var xxdk: T
  @Environment(\.dismiss) private var dismiss

  @FetchAll private var mutedUsers: [ChannelMutedUserModel]

  init(chat: ChatModel, onLeaveChannel: @escaping () -> Void) {
    self.chat = chat
    self.onLeaveChannel = onLeaveChannel
    _mutedUsers = FetchAll(
      ChannelMutedUserModel.where { $0.channelId.eq(chat.channelId ?? "") }
    )
  }

  private var channelId: String? {
    self.chat.channelId
  }

  private func saveNickname() {
    self.controller.saveNickname(channelId: self.channelId, xxdk: self.xxdk)
  }

  var body: some View {
    VStack(spacing: 0) {
      Text("Channel Options")
        .font(.title2)
        .fontWeight(.bold)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)

      ScrollView {
        VStack(spacing: 12) {
          // Channel info
          GroupBox {
            MacSettingRow("Name") {
              Text(self.chat.name)
            }
            if let description = chat.channelDescription, !description.isEmpty {
              Divider()
              MacSettingRow("Description") {
                Text(description)
                  .multilineTextAlignment(.trailing)
              }
            }
          }

          // Your settings
          GroupBox {
            MacSettingRow("Nickname") {
              TextField("Max 24 chars", text: self.$controller.channelNickname)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .onChange(of: self.controller.channelNickname) { _, newValue in
                  self.controller.updateChannelNickname(newValue)
                }
                .onSubmit { self.saveNickname() }
            }
            if self.controller.channelNickname.count > 10 {
              Label(
                "Truncated to 10 chars in display",
                systemImage: "exclamationmark.triangle.fill"
              )
              .font(.caption)
              .foregroundStyle(.orange)
              .frame(maxWidth: .infinity, alignment: .trailing)
            }
            Divider()
            MacSettingRow("Direct Messages") {
              Toggle("", isOn: self.$controller.isDMEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .onChange(of: self.controller.isDMEnabled) { oldValue, newValue in
                  self.controller.toggleDirectMessages(
                    oldValue: oldValue, newValue: newValue,
                    channelId: self.channelId, xxdk: self.xxdk
                  )
                }
            }
          }

          // Invite
          if self.controller.shareURL != nil {
            GroupBox("Invite") {
              if let urlString = controller.shareURL {
                MacSettingRow("Link") {
                  HStack(spacing: 6) {
                    Text(verbatim: urlString)
                      .font(.callout)
                      .foregroundStyle(.secondary)
                      .lineLimit(1)
                      .truncationMode(.middle)
                      .textSelection(.enabled)
                    Button {
                      UIPasteboard.general.string = urlString
                      self.controller.handlePasswordCopied()
                    } label: {
                      Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy invite link")
                  }
                }
              }
              if let sharePassword = controller.sharePassword, !sharePassword.isEmpty {
                Divider()
                MacSettingRow("Password") {
                  HStack(spacing: 6) {
                    Text(sharePassword)
                      .font(.callout.monospaced())
                      .textSelection(.enabled)
                    Button {
                      UIPasteboard.general.string = sharePassword
                      self.controller.handlePasswordCopied()
                    } label: {
                      Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy password")
                  }
                }
              }
            }
          }

          // Admin
          if self.channelId != nil, self.chat.isAdmin {
            GroupBox("Admin") {
              Button("Export Channel Key…") {
                self.controller.activeSheet = .exportKey
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !self.mutedUsers.isEmpty {
              GroupBox("Muted Users") {
                ForEach(self.mutedUsers) { mutedUser in
                  MutedUserRow(pubKey: mutedUser.pubkey) {
                    self.controller.unmuteUser(
                      pubKey: mutedUser.pubkey,
                      channelId: self.channelId,
                      xxdk: self.xxdk
                    )
                  }
                }
              }
            }
          } else if self.channelId != nil {
            GroupBox("Admin") {
              Button("Import Channel Key…") {
                self.controller.activeSheet = .importKey
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }
        .padding(.horizontal, 20)
      }

      // Button bar
      HStack {
        Button("Leave Channel…", role: .destructive) {
          self.controller.showLeaveConfirmation = true
        }

        Spacer()

        Button("Done") {
          self.dismiss()
        }
        .keyboardShortcut(.defaultAction)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 14)
    }
    .frame(width: 480)
    .alert(
      "Leave Channel",
      isPresented: self.$controller.showLeaveConfirmation
    ) {
      Button("Cancel", role: .cancel) {}
      Button("Leave", role: .destructive) {
        self.onLeaveChannel()
        self.dismiss()
      }
    } message: {
      Text("Are you sure you want to leave \"\(self.chat.name)\"?")
    }
    .sheet(item: self.$controller.activeSheet) { sheet in
      Group {
        switch sheet {
        case .exportKey:
          ExportChannelKeySheet(
            channelId: self.channelId ?? "",
            channelName: self.chat.name,
            xxdk: self.xxdk,
            onSuccess: { message in
              self.controller.handleExportSuccess(message: message)
            }
          )
          .frame(minWidth: 420, minHeight: 300)
        case .importKey:
          ImportChannelKeySheet(
            channelId: self.channelId ?? "",
            channelName: self.chat.name,
            xxdk: self.xxdk,
            onSuccess: { message in
              self.controller.handleImportSuccess(
                message: message, chatId: self.chat.id, chat: self.chat
              )
            }
          )
          .frame(minWidth: 420, minHeight: 300)
        }
      }
      .dismissOnOutsideClick()
    }
    .overlay(alignment: .bottom) {
      if let toastMessage = self.controller.toastMessage {
        Text(toastMessage)
          .font(.callout.weight(.medium))
          .foregroundStyle(.white)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(Color.haven, in: Capsule())
          .padding(.bottom, 14)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .onAppear {
      self.controller.onAppear(channelId: self.channelId, xxdk: self.xxdk)
    }
  }
}

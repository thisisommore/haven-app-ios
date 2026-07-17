//
//  MacAccountChip.swift
//  haven
//
//  Account menu shown as a user chip pinned to the bottom of the sidebar
//  (WhatsApp-style): colored avatar derived from your identity, nickname /
//  codename, and the account actions in a pop-up menu.
//

import SQLiteData
import SwiftUI

struct MacAccountChip<T: XXDKP>: View {
  let controller: HomePageController

  @EnvironmentObject private var xxdk: T

  @FetchOne private var selfChat: ChatModel?

  init(controller: HomePageController) {
    self.controller = controller
    _selfChat = FetchOne(ChatModel.where { $0.id.eq(UUID.selfId) })
  }

  private var displayName: String {
    self.controller.currentNickname ?? self.xxdk.codename ?? "Account"
  }

  private var avatarColor: Color {
    Color(hexNumber: self.selfChat?.color ?? 0xFF9300)
  }

  private var initial: String {
    String(self.displayName.prefix(1)).uppercased()
  }

  var body: some View {
    Menu {
      Button("My QR Code…") { self.controller.openShareQRCode(xxdk: self.xxdk) }
      Button("Nickname…") { self.controller.activeSheet = .nicknamePicker }
      Button("Export Identity…") { self.controller.activeSheet = .exportIdentity }
      Divider()
      Button("Log Out…", role: .destructive) { self.controller.showLogoutAlert = true }
    } label: {
      HStack(spacing: 10) {
        ZStack {
          Circle().fill(self.avatarColor)
          Text(self.initial)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
        }
        .frame(width: 28, height: 28)

        VStack(alignment: .leading, spacing: 1) {
          Text(self.displayName)
            .font(.callout.weight(.medium))
            .lineLimit(1)
          if self.controller.currentNickname != nil, let codename = xxdk.codename {
            Text("aka \(codename)")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }

        Spacer()

        Image(systemName: "ellipsis")
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .contentShape(Rectangle())
    }
    .menuIndicator(.hidden)
    .buttonStyle(.plain)
    .background(.bar)
    .overlay(alignment: .top) {
      Divider()
    }
  }
}

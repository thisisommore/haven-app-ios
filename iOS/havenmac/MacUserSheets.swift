//
//  MacUserSheets.swift
//  haven
//
//  Account sheets for the mac app: nickname editor, QR contact card, and
//  identity export. Compact mac-styled dialogs driving the shared XXDKP API.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Nickname

struct MacNicknameSheet<T: XXDKP>: View {
  @EnvironmentObject private var xxdk: T
  @Environment(\.dismiss) private var dismiss

  @State private var nickname = ""

  private func save() {
    let trimmed = String(self.nickname.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
    try? self.xxdk.dm.setNickname(trimmed)
    self.dismiss()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Nickname")
        .font(.headline)

      TextField("Nickname", text: self.$nickname)
        .textFieldStyle(.roundedBorder)
        .onSubmit(self.save)

      Text("Shown to your contacts instead of your codename. Maximum 24 characters.")
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack {
        Spacer()
        Button("Cancel") { self.dismiss() }
        Button("Save", action: self.save)
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 360)
    .onAppear {
      self.nickname = (try? self.xxdk.dm.getNickname()) ?? ""
    }
  }
}

// MARK: - QR contact card

struct MacQRCodeSheet: View {
  let data: QRData

  @State private var copied = false

  private var urlString: String {
    "haven://dm?token=\(self.data.token)&pubKey=\(self.data.pubKey.base64EncodedString())&codeset=\(self.data.codeset)"
  }

  private var qrImage: NSImage? {
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    filter.setValue(Data(self.urlString.utf8), forKey: "inputMessage")
    filter.setValue("H", forKey: "inputCorrectionLevel")
    guard let output = filter.outputImage else { return nil }
    let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
    guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
    return NSImage(cgImage: cgImage, size: NSSize(width: scaled.extent.width, height: scaled.extent.height))
  }

  var body: some View {
    VStack(spacing: 16) {
      Text("My QR Code")
        .font(.headline)

      if let qrImage {
        Image(nsImage: qrImage)
          .resizable()
          .interpolation(.none)
          .frame(width: 220, height: 220)
          .padding(12)
          .background(.white, in: RoundedRectangle(cornerRadius: 12))
      }

      Text("Anyone with this code can message you directly. Share it only with people you trust.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      HStack {
        Button(self.copied ? "Copied!" : "Copy Link") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(self.urlString, forType: .string)
          self.copied = true
          Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { self.copied = false }
          }
        }
        ShareLink(item: self.urlString)
      }
    }
    .padding(24)
    .frame(width: 320)
  }
}

// MARK: - Export identity

struct MacExportIdentitySheet<T: XXDKP>: View {
  @EnvironmentObject private var xxdk: T
  @Environment(\.dismiss) private var dismiss

  @State private var password = ""
  @State private var errorMessage: String?
  @State private var exported = false

  private func export() {
    do {
      let data = try self.xxdk.exportIdentity(password: self.password)

      let panel = NSSavePanel()
      panel.nameFieldStringValue = "\(self.xxdk.codename ?? "haven")_export.json"
      panel.allowedContentTypes = [.json]
      guard panel.runModal() == .OK, let url = panel.url else { return }

      try data.write(to: url)
      self.exported = true
      self.dismiss()
    } catch {
      self.errorMessage = error.localizedDescription
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Export Identity")
        .font(.headline)

      Text("Your identity is encrypted with the password you choose here. Keep the export file private.")
        .font(.caption)
        .foregroundStyle(.secondary)

      SecureField("Export password", text: self.$password)
        .textFieldStyle(.roundedBorder)
        .onSubmit(self.export)

      if let errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(.red)
      }

      HStack {
        Spacer()
        Button("Cancel") { self.dismiss() }
        Button("Export…", action: self.export)
          .keyboardShortcut(.defaultAction)
          .disabled(self.password.isEmpty)
      }
    }
    .padding(20)
    .frame(width: 380)
  }
}

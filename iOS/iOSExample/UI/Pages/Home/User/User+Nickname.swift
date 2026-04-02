//
//  User+Nickname.swift
//  iOSExample
//

import SwiftUI

struct NicknamePickerSheet<T: XXDKP>: View {
  let codename: String

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var xxdk: T

  @State private var nickname: String = ""
  @State private var isSaving: Bool = false
  @State private var errorMessage: String?
  @FocusState private var isNicknameFocused: Bool

  private let maxNicknameLength = 24

  private var displayName: String {
    if self.nickname.isEmpty {
      return self.codename
    }
    let truncatedNick = self.nickname.count > 10 ? String(self.nickname.prefix(10)) + "…" : self.nickname
    return "\(truncatedNick) aka \(self.codename)"
  }

  private var nicknameInput: some View {
    VStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Nickname")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Spacer()
          Text("\(self.nickname.count)/\(self.maxNicknameLength)")
            .font(.caption)
            .foregroundStyle(self.nickname.count > self.maxNicknameLength ? .red : .secondary)
        }

        HStack(spacing: 12) {
          Image(systemName: "person.text.rectangle")
            .foregroundColor(.haven)
            .frame(width: 20)
          TextField("Enter nickname", text: self.$nickname)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .focused(self.$isNicknameFocused)
            .onChange(of: self.nickname) { _, newValue in
              if newValue.count > self.maxNicknameLength {
                self.nickname = String(newValue.prefix(self.maxNicknameLength))
              }
            }

          if !self.nickname.isEmpty {
            Button {
              self.nickname = ""
            } label: {
              Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.haven)
            }
          }
        }
        .padding()
        .background(
          self.isNicknameFocused ? Color.haven.opacity(0.08) : Color(.secondarySystemBackground)
        )
        .cornerRadius(10)
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .stroke(self.isNicknameFocused ? Color.haven : Color.clear, lineWidth: 1.5)
        )
      }

      if self.nickname.count > 10 {
        HStack(spacing: 6) {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.orange)
          Text("Nickname will be truncated to 10 chars in display")
            .font(.caption)
            .foregroundColor(.orange)
        }
      }

      if let errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundColor(.red)
      }
    }
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 20)
        .fill(Color(.systemBackground))
    )
  }

  private var infoSection: some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        Image(systemName: "bubble.left.and.bubble.right")
          .foregroundStyle(.haven)
        Text("This nickname applies to Direct Messages only.")
          .font(.footnote)
          .fontWeight(.medium)
          .foregroundStyle(.primary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: 12) {
        Image(systemName: "info.circle.fill")
          .foregroundStyle(.haven)
        Text(
          "Your nickname is sent with every DM message. Recipients will see this instead of your codename."
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: 12) {
        Image(systemName: "number.square")
          .foregroundStyle(.haven)
        Text("For channels, set your nickname in each channel's settings.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: 12) {
        Image(systemName: "textformat.size")
          .foregroundStyle(.haven)
        Text("Nicknames longer than 10 chars are truncated in display to prevent scams.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: 12) {
        Image(systemName: "arrow.triangle.2.circlepath")
          .foregroundStyle(.haven)
        Text("Leave empty to use your codename.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 20)
        .fill(Color(.systemBackground))
    )
  }

  private func loadCurrentNickname() {
    do {
      let currentNickname = try xxdk.dm!.getNickname()
      self.nickname = currentNickname
    } catch {
      // No nickname set, leave empty
      self.nickname = ""
    }
  }

  private func saveNickname() {
    self.isSaving = true
    self.errorMessage = nil

    do {
      try self.xxdk.dm!.setNickname(self.nickname)
      self.dismiss()
    } catch {
      self.errorMessage = "Failed to save: \(error.localizedDescription)"
    }

    self.isSaving = false
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 28) {
          // Nickname input
          self.nicknameInput

          // Info text
          self.infoSection

          Spacer(minLength: 40)
        }
        .padding(.horizontal, 20)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("DM Nickname")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") { self.dismiss() }
            .tint(.haven)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Save") { self.saveNickname() }
            .fontWeight(.semibold)
            .tint(.haven)
            .disabled(self.isSaving)
        }
      }
      .onAppear { self.loadCurrentNickname() }
    }
  }
}

#Preview {
  NicknamePickerSheet<XXDKMock>(codename: "juniorFunkyAntiquity")
    .mock()
}

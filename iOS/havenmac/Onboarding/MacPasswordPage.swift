//
//  MacPasswordPage.swift
//  haven
//
//  First-run password creation, redesigned for the Mac: a centered column
//  with native controls instead of the phone full-bleed layout.
//  Logic mirrors the shared iOS `PasswordCreationView`.
//

import Dependencies
import SwiftUI

struct MacPasswordPage<T: XXDKP>: View {
  @EnvironmentObject var xxdk: T
  @EnvironmentObject var navigation: AppNavigationPath

  @Dependency(\.appStorage) private var appStorage

  @State private var password = ""
  @State private var confirm = ""
  @State private var attemptedSubmit = false
  @State private var isLoading = false
  @State private var ndfTask: Task<Data, Never>?
  @State private var showImportSheet = false
  @State private var importPassword = ""

  @FocusState private var focusedField: PasswordField?

  private var failingRules: [PasswordRule] {
    PasswordRule.allCases.filter { !$0.isSatisfied(by: self.password) }
  }

  private var passwordsMatch: Bool {
    !self.password.isEmpty && self.password == self.confirm
  }

  private var canContinue: Bool {
    self.password.count >= 1 && self.passwordsMatch
  }

  private var strength: Double {
    let satisfied = Double(PasswordRule.allCases.count - self.failingRules.count)
    return max(0, min(1, satisfied / Double(PasswordRule.allCases.count)))
  }

  private var strengthLabel: String {
    switch self.strength {
    case ..<0.4: return "Weak"
    case ..<0.8: return "Okay"
    default: return "Strong"
    }
  }

  private func handleAppear() {
    if self.ndfTask == nil {
      self.ndfTask = Task {
        await self.xxdk.downloadNdf()
      }
    }
  }

  private func handleSubmit() {
    self.attemptedSubmit = true
    guard self.canContinue else { return }

    try! self.appStorage.storePassword(self.password)
    self.isLoading = true
    let ndfTask = self.ndfTask ?? Task { await self.xxdk.downloadNdf() }
    self.ndfTask = ndfTask

    Task.detached {
      let ndf = await ndfTask.value
      await self.xxdk.newCmix(downloadedNdf: ndf)

      await MainActor.run {
        self.password = ""
        self.confirm = ""
        self.attemptedSubmit = false
        self.isLoading = false
        self.focusedField = nil
        self.importPassword = ""
        self.navigation.path.append(Destination.codenameGenerator)
      }
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      VStack(alignment: .leading, spacing: 22) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Join the alpha")
            .font(.largeTitle)
            .fontWeight(.bold)
          Text("Enter a password to secure your Haven identity")
            .foregroundStyle(.secondary)
        }

        VStack(spacing: 12) {
          SecureField("New password", text: self.$password)
            .textFieldStyle(.roundedBorder)
            .focused(self.$focusedField, equals: .password)
            .onSubmit { self.focusedField = .confirm }

          SecureField("Confirm password", text: self.$confirm)
            .textFieldStyle(.roundedBorder)
            .focused(self.$focusedField, equals: .confirm)
            .onSubmit { self.handleSubmit() }

          if self.attemptedSubmit && !self.passwordsMatch {
            Label("Passwords don't match", systemImage: "exclamationmark.triangle.fill")
              .font(.callout)
              .foregroundStyle(.orange)
          }
        }

        VStack(alignment: .leading, spacing: 6) {
          ForEach(PasswordRule.allCases, id: \.self) { rule in
            let ok = rule.isSatisfied(by: self.password)
            HStack(spacing: 8) {
              Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(ok ? Color.haven : Color.secondary)
                .imageScale(.small)
              Text(rule.label)
                .font(.caption)
                .foregroundStyle(ok ? .primary : .secondary)
            }
          }

          if !self.password.isEmpty {
            HStack(spacing: 8) {
              ProgressView(value: self.strength)
                .tint(.haven)
              Text(self.strengthLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
            }
          }
        }

        VStack(spacing: 10) {
          Button(action: self.handleSubmit) {
            HStack {
              if self.isLoading {
                ProgressView()
                  .controlSize(.small)
                Text(self.xxdk.status.message)
                  .lineLimit(1)
              } else {
                Text("Continue")
                  .frame(maxWidth: .infinity)
              }
            }
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .tint(.haven)
          .disabled(!self.canContinue || self.isLoading)
          .keyboardShortcut(.defaultAction)

          Button("Import an existing account") {
            self.showImportSheet = true
          }
          .buttonStyle(.plain)
          .foregroundStyle(.haven)
        }
      }
      .frame(width: 360)

      Spacer()
      Spacer()
    }
    .frame(maxWidth: .infinity)
    .navigationBarBackButtonHidden()
    .privacySensitive()
    .onAppear { self.handleAppear() }
    .sheet(isPresented: self.$showImportSheet) {
      ImportAccountSheet<T>(
        importPassword: self.$importPassword,
        ndfTask: self.ndfTask
      )
      .frame(minWidth: 420, minHeight: 360)
      .dismissOnOutsideClick()
    }
  }
}

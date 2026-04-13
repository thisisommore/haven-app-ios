import Dependencies
import SQLiteData
import SwiftUI

@MainActor
struct PasswordCreationView<T: XXDKP>: View {
  @EnvironmentObject var xxdk: T
  @EnvironmentObject var navigation: AppNavigationPath
  @Dependency(\.appStorage) private var appStorage

  @State private var password: String = ""
  @State private var confirm: String = ""
  @State private var attemptedSubmit: Bool = false
  @State private var isLoading = false
  @State private var ndfTask: Task<Data, Never>?
  @State private var showImportSheet: Bool = false
  @State private var importPassword: String = ""

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

  private var strengthColor: Color {
    switch self.strength {
    case ..<0.8: return BranchColor.primary.opacity(0.8)
    default: return BranchColor.primary
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

  private func strengthLabel(for value: Double) -> String {
    switch value {
    case ..<0.4: return "Weak"
    case ..<0.8: return "Okay"
    default: return "Strong"
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Enter a password to secure your Haven identity")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .onAppear { self.handleAppear() }

        VStack(spacing: 14) {
          LabeledSecureField(
            title: "New password",
            text: self.$password,
            isInvalid: self.attemptedSubmit && self.password.isEmpty,
            isFocused: self.focusedField == .password
          )
          .focused(self.$focusedField, equals: .password)
          .submitLabel(.next)
          .onSubmit { self.focusedField = .confirm }

          LabeledSecureField(
            title: "Confirm password",
            text: self.$confirm,
            isInvalid: self.attemptedSubmit && !self.passwordsMatch,
            isFocused: self.focusedField == .confirm
          )
          .focused(self.$focusedField, equals: .confirm)
          .submitLabel(.continue)
          .onSubmit { self.handleSubmit() }
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("Password recommendation")
          ForEach(PasswordRule.allCases, id: \.self) { rule in
            let ok = rule.isSatisfied(by: self.password)
            HStack(spacing: 8) {
              Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(ok ? BranchColor.primary : .secondary)
              Text(rule.label)
                .foregroundStyle(ok ? .primary : .secondary)
                .strikethrough(ok, color: .secondary)
                .accessibilityLabel("\(rule.label) \(ok ? "satisfied" : "not satisfied")")
            }
            .font(.footnote)
          }

          if !self.confirm.isEmpty || self.attemptedSubmit {
            HStack(spacing: 8) {
              Image(
                systemName: self.passwordsMatch
                  ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
              )
              .foregroundStyle(self.passwordsMatch ? BranchColor.primary : .haven)
              Text(self.passwordsMatch ? "Passwords match" : "Passwords don't match")
            }
            .font(.footnote)
            .transition(.move(edge: .top).combined(with: .opacity))
          }

          VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: self.strength)
              .tint(self.strengthColor)
            Text("Strength: \(self.strengthLabel(for: self.strength))")
              .font(.caption)
              .foregroundStyle(self.strengthColor)
          }
          .opacity(self.password.isEmpty ? 0 : 1)
          .animation(.easeInOut, value: self.password)
        }

        Button(action: { self.showImportSheet = true }) {
          Text("Import an existing account").bold()
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
        }
        .buttonStyle(BranchButtonStyle(isEnabled: true))
      }
      .onTapGesture { self.focusedField = nil }
      .animation(.easeInOut(duration: 0.3), value: !self.confirm.isEmpty || self.attemptedSubmit)
      .padding(.horizontal, 20)
      .padding(.top, 28)
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .navigationTitle("Join the alpha")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(action: self.handleSubmit) {
            HStack {
              if self.isLoading {
                ProgressView().frame(width: 16, height: 16)
              }
              Text(self.isLoading ? self.xxdk.status.message : "Continue")
                .fontWeight((!self.canContinue || self.isLoading) ? .regular : .bold)
                .foregroundStyle((!self.canContinue || self.isLoading) ? .gray : .haven)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
          }
          .disabled(!self.canContinue || self.isLoading)
          .privacySensitive()
        }.hiddenSharedBackground()
      }
    }
    .ignoresSafeArea(.keyboard, edges: .bottom)
    .privacySensitive()
    .sheet(isPresented: self.$showImportSheet) {
      ImportAccountSheet<T>(
        importPassword: self.$importPassword,
        ndfTask: self.ndfTask
      )
    }
  }
}

enum PasswordField { case password, confirm }

enum PasswordRule: CaseIterable {
  case length, upper, lower, digit, symbol

  var label: String {
    switch self {
    case .length: return "At least 8 characters"
    case .upper: return "Contains an uppercase letter"
    case .lower: return "Contains a lowercase letter"
    case .digit: return "Contains a number"
    case .symbol: return "Contains a symbol (!@#$…)"
    }
  }

  func isSatisfied(by s: String) -> Bool {
    switch self {
    case .length: return s.count >= 8
    case .upper: return s.range(of: "[A-Z]", options: .regularExpression) != nil
    case .lower: return s.range(of: "[a-z]", options: .regularExpression) != nil
    case .digit: return s.range(of: "[0-9]", options: .regularExpression) != nil
    case .symbol: return s.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
    }
  }
}

struct BranchButtonStyle: SwiftUI.ButtonStyle {
  let isEnabled: Bool
  var isSecondary: Bool = false
  @Environment(\.colorScheme) private var colorScheme

  func makeBody(configuration: SwiftUI.ButtonStyleConfiguration) -> some View {
    configuration.label
      .padding(.vertical, 14)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(
            self.isEnabled
              ? (self.isSecondary ? BranchColor.secondary : BranchColor.primary)
              : self.disabledColor
          )
          .animation(.easeInOut(duration: 0.3), value: self.isEnabled)
      )
      .opacity(self.isEnabled ? 1.0 : self.disabledOpacity)
      .scaleEffect(configuration.isPressed && self.isEnabled ? 0.98 : 1.0)
      .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
  }

  private var disabledColor: Color {
    self.colorScheme == .dark ? Color(.systemGray4) : .gray.opacity(0.4)
  }

  private var disabledOpacity: Double {
    self.colorScheme == .dark ? 0.5 : 1.0
  }
}

enum BranchColor {
  static let primary = Color.haven
  static let secondary = Color(red: 180 / 255, green: 140 / 255, blue: 60 / 255)
  static let disabled = Color(red: 236 / 255, green: 186 / 255, blue: 96 / 255).opacity(0.5)
  static let light = Color(red: 246 / 255, green: 206 / 255, blue: 136 / 255)
}

#Preview {
  Mock {
    PasswordCreationView<XXDKMock>()
      .environmentObject(AppNavigationPath())
  }
}

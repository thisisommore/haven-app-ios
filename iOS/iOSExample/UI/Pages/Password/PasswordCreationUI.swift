import SwiftUI

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

struct PasswordCreationUI<T: XXDKP>: View {
  // States
  @Binding var password: String
  @Binding var confirm: String
  @Binding var attemptedSubmit: Bool
  @Binding var isLoading: Bool
  @Binding var showImportSheet: Bool
  @Binding var importPassword: String
  @FocusState.Binding var focusedField: PasswordField?

  // Computed states passed in
  let canContinue: Bool
  let passwordsMatch: Bool
  let strength: Double
  let strengthColor: Color
  let statusText: String

  // Callbacks
  var onSubmit: () -> Void
  var onImportTapped: () -> Void
  var onAppear: () -> Void
  var ndfTask: Task<Data, Never>?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Enter a password to secure your Haven identity")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .onAppear { self.onAppear() }

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
          .onSubmit { self.onSubmit() }
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
              .foregroundStyle(self.passwordsMatch ? BranchColor.primary : .orange)
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

        Button(action: self.onImportTapped) {
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
          Button(action: self.onSubmit) {
            HStack {
              if self.isLoading {
                ProgressView().frame(width: 16, height: 16)
              }
              Text(self.isLoading ? self.statusText : "Continue")
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

  private func strengthLabel(for value: Double) -> String {
    switch value {
    case ..<0.4: return "Weak"
    case ..<0.8: return "Okay"
    default: return "Strong"
    }
  }
}

struct BranchButtonStyle: ButtonStyle {
  let isEnabled: Bool
  var isSecondary: Bool = false
  @Environment(\.colorScheme) private var colorScheme

  func makeBody(configuration: Configuration) -> some View {
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

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Enter a password to secure your Haven identity")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .onAppear { onAppear() }

                VStack(spacing: 14) {
                    LabeledSecureField(
                        title: "New password",
                        text: $password,
                        isInvalid: attemptedSubmit && password.isEmpty,
                        isFocused: focusedField == .password
                    )
                    .focused($focusedField, equals: .password)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirm }

                    LabeledSecureField(
                        title: "Confirm password",
                        text: $confirm,
                        isInvalid: attemptedSubmit && !passwordsMatch,
                        isFocused: focusedField == .confirm
                    )
                    .focused($focusedField, equals: .confirm)
                    .submitLabel(.continue)
                    .onSubmit { onSubmit() }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Password recommendation")
                    ForEach(PasswordRule.allCases, id: \.self) { rule in
                        let ok = rule.isSatisfied(by: password)
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

                    if !confirm.isEmpty || attemptedSubmit {
                        HStack(spacing: 8) {
                            Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(passwordsMatch ? BranchColor.primary : .orange)
                            Text(passwordsMatch ? "Passwords match" : "Passwords don't match")
                        }
                        .font(.footnote)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: strength)
                            .tint(strengthColor)
                        Text("Strength: \(strengthLabel(for: strength))")
                            .font(.caption)
                            .foregroundStyle(strengthColor)
                    }
                    .opacity(password.isEmpty ? 0 : 1)
                    .animation(.easeInOut, value: password)
                }

                Button(action: onImportTapped) {
                    Text("Import an existing account").bold()
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                }
                .buttonStyle(BranchButtonStyle(isEnabled: true))
            }
            .onTapGesture { focusedField = nil }
            .animation(.easeInOut(duration: 0.3), value: !confirm.isEmpty || attemptedSubmit)
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .navigationTitle("Join the alpha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onSubmit) {
                        HStack {
                            if isLoading {
                                ProgressView().frame(width: 16, height: 16)
                            }
                            Text(isLoading ? statusText : "Continue")
                                .fontWeight((!canContinue || isLoading) ? .regular : .bold)
                                .foregroundStyle((!canContinue || isLoading) ? .gray : .haven)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                    }
                    .disabled(!canContinue || isLoading)
                    .privacySensitive()
                }.hiddenSharedBackground()
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .privacySensitive()
        .sheet(isPresented: $showImportSheet) {
            ImportAccountSheet<T>(importPassword: $importPassword)
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
                        isEnabled
                            ? (isSecondary ? BranchColor.secondary : BranchColor.primary)
                            : disabledColor
                    )
                    .animation(.easeInOut(duration: 0.3), value: isEnabled)
            )
            .opacity(isEnabled ? 1.0 : disabledOpacity)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }

    private var disabledColor: Color {
        colorScheme == .dark ? Color(.systemGray4) : .gray.opacity(0.4)
    }

    private var disabledOpacity: Double {
        colorScheme == .dark ? 0.5 : 1.0
    }
}

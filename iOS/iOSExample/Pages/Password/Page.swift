import SwiftData
import SwiftUI

@MainActor
public struct PasswordCreationView: View {
    @State private var password: String = ""
    @State private var confirm: String = ""
    @State private var attemptedSubmit: Bool = false
    @State private var isLoading = false
    @FocusState private var focusedField: PasswordField?
    @State private var showImportSheet: Bool = false
    @State private var importPassword: String = ""
    
    @EnvironmentObject var sm: SecretManager
    @EnvironmentObject var xxdk: XXDK
    @EnvironmentObject var swiftDataActor: SwiftDataActor
    @EnvironmentObject var navigation: AppNavigationPath

    private var failingRules: [PasswordRule] {
        PasswordRule.allCases.filter { !$0.isSatisfied(by: password) }
    }

    private var passwordsMatch: Bool {
        !password.isEmpty && password == confirm
    }

    private var canContinue: Bool { password.count >= 1 && passwordsMatch }

    private var strength: Double {
        let satisfied = Double(PasswordRule.allCases.count - failingRules.count)
        return max(0, min(1, satisfied / Double(PasswordRule.allCases.count)))
    }

    private var strengthColor: Color {
        switch strength {
        case ..<0.8: return BranchColor.primary.opacity(0.8)
        default: return BranchColor.primary
        }
    }

    public var body: some View {
        PasswordCreationUI(
            password: $password,
            confirm: $confirm,
            attemptedSubmit: $attemptedSubmit,
            isLoading: $isLoading,
            showImportSheet: $showImportSheet,
            importPassword: $importPassword,
            focusedField: $focusedField,
            canContinue: canContinue,
            passwordsMatch: passwordsMatch,
            strength: strength,
            strengthColor: strengthColor,
            statusText: xxdk.status,
            onSubmit: handleSubmit,
            onImportTapped: { showImportSheet = true },
            onAppear: handleAppear
        )
    }

    private func handleAppear() {
        Task.detached {
            await xxdk.downloadNdf()
        }
    }

    private func handleSubmit() {
        attemptedSubmit = true
        guard canContinue else { return }

        try! sm.storePassword(password)
        isLoading = true

        Task.detached {
            await xxdk.setUpCmix()

            await MainActor.run {
                print("append time")
                password = ""
                confirm = ""
                attemptedSubmit = false
                isLoading = false
                focusedField = nil
                importPassword = ""
                navigation.path.append(Destination.codenameGenerator)
            }
        }
    }
}


enum BranchColor {
    static let primary = Color.haven
    static let secondary = Color(red: 180 / 255, green: 140 / 255, blue: 60 / 255)
    static let disabled = Color(red: 236 / 255, green: 186 / 255, blue: 96 / 255).opacity(0.5)
    static let light = Color(red: 246 / 255, green: 206 / 255, blue: 136 / 255)
}


#Preview {
    PasswordCreationView()
        .environmentObject(SecretManager())
        .environmentObject(XXDK())
        .environmentObject(
            SwiftDataActor(
                previewModelContainer: try! ModelContainer(
                    for: Schema([]),
                    configurations: []
                )
            )
        )
        .environmentObject(AppNavigationPath())
}

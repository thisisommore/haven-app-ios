import SQLiteData
import SwiftUI

@MainActor
struct PasswordCreationView<T: XXDKP>: View {
  @State private var password: String = ""
  @State private var confirm: String = ""
  @State private var attemptedSubmit: Bool = false
  @State private var isLoading = false
  @FocusState private var focusedField: PasswordField?
  @State private var showImportSheet: Bool = false
  @State private var importPassword: String = ""

  @EnvironmentObject var appStorage: AppStorage
  @EnvironmentObject var xxdk: T
  @EnvironmentObject var navigation: AppNavigationPath

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

  var body: some View {
    PasswordCreationUI<T>(
      password: self.$password,
      confirm: self.$confirm,
      attemptedSubmit: self.$attemptedSubmit,
      isLoading: self.$isLoading,
      showImportSheet: self.$showImportSheet,
      importPassword: self.$importPassword,
      focusedField: self.$focusedField,
      canContinue: self.canContinue,
      passwordsMatch: self.passwordsMatch,
      strength: self.strength,
      strengthColor: self.strengthColor,
      statusText: self.xxdk.status,
      onSubmit: self.handleSubmit,
      onImportTapped: { self.showImportSheet = true },
      onAppear: self.handleAppear
    )
  }

  private func handleAppear() {
    Task.detached {
      await self.xxdk.downloadNdf()
    }
  }

  private func handleSubmit() {
    self.attemptedSubmit = true
    guard self.canContinue else { return }

    try! self.appStorage.storePassword(self.password)
    self.isLoading = true

    Task.detached {
      await self.xxdk.setUpCmix()

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
}

enum BranchColor {
  static let primary = Color.haven
  static let secondary = Color(red: 180 / 255, green: 140 / 255, blue: 60 / 255)
  static let disabled = Color(red: 236 / 255, green: 186 / 255, blue: 96 / 255).opacity(0.5)
  static let light = Color(red: 246 / 255, green: 206 / 255, blue: 136 / 255)
}

#Preview {
  PasswordCreationView<XXDKMock>()
    .environmentObject(AppStorage())
    .environmentObject(AppNavigationPath())
    .mock()
}

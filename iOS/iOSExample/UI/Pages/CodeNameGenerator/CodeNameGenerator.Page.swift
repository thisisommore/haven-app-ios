import SwiftUI

struct Codename: Identifiable {
  let id = UUID()
  let text: String
  let color: Color
}

struct CodenameGeneratorView<T: XXDKP>: View {
  @EnvironmentObject private var xxdk: T
  @EnvironmentObject private var navigation: AppNavigationPath

  @State private var codenames: [Codename] = []
  @State private var selectedCodename: Codename?
  @State private var isGenerating = false
  @State private var generatedIdentities: [GeneratedIdentity] = []

  private let colors: [Color] = [
    .blue, .green, .orange, .purple, .pink, .red, .cyan, .mint, .indigo, .teal,
  ]

  private func generateCodenames() {
    self.isGenerating = true
    let impact = UIImpactFeedbackGenerator(style: .medium)
    impact.impactOccurred()

    withAnimation(.easeOut(duration: 0.3)) {
      self.selectedCodename = nil
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      // Generate identities using XXDK
      let newGeneratedIdentities = self.xxdk.generateIdentities(amountOfIdentities: 10)
      self.generatedIdentities = newGeneratedIdentities

      withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
        if newGeneratedIdentities.isEmpty {
          AppLogger.identity.error("No identities generated")
          // Could show an error message to the user here
        } else {
          self.codenames = newGeneratedIdentities.enumerated().map { index, identity in
            let color = self.colors[index % self.colors.count]
            return Codename(text: identity.codename, color: color)
          }
        }
        self.isGenerating = false
      }
    }
  }

  private func claimCodename() {
    guard let selected = selectedCodename else { return }

    // Find the corresponding identity from generatedIdentities
    guard let identity = generatedIdentities.first(where: { $0.codename == selected.text })
    else {
      AppLogger.identity.error(
        "Could not find identity for codename: \(selected.text, privacy: .public)"
      )
      return
    }

    // Store the private identity in XXDK for later use
    // This would typically be stored securely for the user's identity

    let success = UINotificationFeedbackGenerator()
    success.notificationOccurred(.success)
    Task {
      await self.xxdk.setupClients(privateIdentity: identity.privateIdentity) {
        do {
          try self.xxdk.savePrivateIdentity(privateIdentity: identity.privateIdentity)
        } catch {
          fatalError("failed to save private identity in cmix ekv: \(error.localizedDescription)")
        }
      }
    }
    self.navigation.path.append(Destination.landing)
  }

  var body: some View {
    VStack(spacing: 0) {
      // Header with icon
      CodeNameGenHeaderView()
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)

      // Codenames list
      ScrollView {
        LazyVStack(spacing: 12) {
          ForEach(Array(self.codenames.enumerated()), id: \.element.id) { _, codename in
            CodenameCard(
              codename: codename,
              isSelected: self.selectedCodename?.id == codename.id
            )
            .onTapGesture {
              withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                self.selectedCodename = codename
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
              }
            }
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
      }

      // Bottom action buttons
      BottomActionsView(
        selectedCodename: self.selectedCodename,
        onGenerate: self.generateCodenames,
        onClaim: self.claimCodename,
        isGenerating: self.$isGenerating
      )
      .padding(.horizontal, 20)
      .padding(.vertical, 20)
    }
    .background(Color(uiColor: .systemBackground))
    .onAppear {
      Task.detached {
        await self.xxdk.startNetworkFollower()
      }
      if self.codenames.isEmpty && !self.isGenerating {
        self.generateCodenames()
      }
    }
  }
}

#Preview("Codename Generator") {
  CodenameGeneratorView<XXDKMock>()
    .mock()
}

#Preview("Dark Mode") {
  CodenameGeneratorView<XXDKMock>()
    .preferredColorScheme(.dark)
    .mock()
}

#Preview("Individual Cards") {
  VStack(spacing: 12) {
    CodenameCard(
      codename: Codename(text: "electorAngelicBoating", color: .blue),
      isSelected: false
    )

    CodenameCard(
      codename: Codename(text: "brotherTrifidCathouse", color: .purple),
      isSelected: true
    )

    CodenameCard(
      codename: Codename(text: "recruitMutativeVocal", color: .orange),
      isSelected: false
    )
  }
  .padding()
  .background(Color(uiColor: .systemBackground))
}

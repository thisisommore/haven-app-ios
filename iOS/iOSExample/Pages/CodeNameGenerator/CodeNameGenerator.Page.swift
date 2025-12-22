import SwiftUI

struct Codename: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
}

struct CodenameGeneratorView<T: XXDKP>: View {
    @State private var codenames: [Codename] = []
    @State private var selectedCodename: Codename?
    @State private var isGenerating = false
    @State private var generatedIdentities: [GeneratedIdentity] = []
    @EnvironmentObject private var xxdk: T
    @EnvironmentObject private var navigation: AppNavigationPath
    private let adjectives1 = [
        "elector", "brother", "recruit", "clever", "swift", "mystic", "cosmic",
        "quantum", "stellar", "cyber", "digital", "neural", "atomic", "solar",
        "lunar", "phantom", "cipher", "vector", "omega", "delta",
    ]

    private let adjectives2 = [
        "Angelic", "Trifid", "Mutative", "Silent", "Golden", "Crystal", "Phantom",
        "Frozen", "Blazing", "Hidden", "Ancient", "Modern", "Virtual", "Infinite",
        "Mystic", "Cosmic", "Radiant", "Neon", "Prism", "Stellar",
    ]

    private let nouns = [
        "Boating", "Cathouse", "Vocal", "Thunder", "Whisper", "Shadow", "Phoenix",
        "Dragon", "Storm", "Nexus", "Matrix", "Cipher", "Enigma", "Prism",
        "Vertex", "Pulse", "Echo", "Flux", "Zen", "Aura",
    ]

    private let colors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .red, .cyan, .mint, .indigo, .teal,
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header with icon
            HeaderView()
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)

            // Codenames list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(codenames.enumerated()), id: \.element.id) { _, codename in
                        CodenameCard(
                            codename: codename,
                            isSelected: selectedCodename?.id == codename.id
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                selectedCodename = codename
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
                isGenerating: $isGenerating,
                selectedCodename: selectedCodename,
                onGenerate: generateCodenames,
                onClaim: claimCodename
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            Task.detached {
                await xxdk.startNetworkFollower()
            }
            if codenames.isEmpty && !isGenerating {
                generateCodenames()
            }
        }
    }

    private func generateCodenames() {
        isGenerating = true
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        withAnimation(.easeOut(duration: 0.3)) {
            selectedCodename = nil
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Generate identities using XXDK
            let newGeneratedIdentities = xxdk.generateIdentities(amountOfIdentities: 10)
            generatedIdentities = newGeneratedIdentities

            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                if newGeneratedIdentities.isEmpty {
                    print("ERROR: No identities generated")
                    // Could show an error message to the user here
                } else {
                    codenames = newGeneratedIdentities.enumerated().map { index, identity in
                        let color = colors[index % colors.count]
                        return Codename(text: identity.codename, color: color)
                    }
                }
                isGenerating = false
            }
        }
    }

    private func claimCodename() {
        guard let selected = selectedCodename else { return }

        // Find the corresponding identity from generatedIdentities
        guard let identity = generatedIdentities.first(where: { $0.codename == selected.text }) else {
            print("ERROR: Could not find identity for codename: \(selected.text)")
            return
        }

        // Store the private identity in XXDK for later use
        // This would typically be stored securely for the user's identity
        print("✅ Claimed codename: \(selected.text)")
        print("Private identity stored for later use")

        let success = UINotificationFeedbackGenerator()
        success.notificationOccurred(.success)
        Task {
            await xxdk.load(privateIdentity: identity.privateIdentity)
        }
        navigation.path.append(Destination.landing)
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

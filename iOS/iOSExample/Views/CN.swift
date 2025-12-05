import SwiftUI

struct Codename: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
}

struct CodenameGeneratorView: View {
    @State private var codenames: [Codename] = []
    @State private var selectedCodename: Codename?
    @State private var isGenerating = false
    @State private var generatedIdentities: [GeneratedIdentity] = []
    @EnvironmentObject private var xxdk: XXDK
    @Environment(\.navigation) private var navigation
    private let adjectives1 = [
        "elector", "brother", "recruit", "clever", "swift", "mystic", "cosmic",
        "quantum", "stellar", "cyber", "digital", "neural", "atomic", "solar",
        "lunar", "phantom", "cipher", "vector", "omega", "delta"
    ]
    
    private let adjectives2 = [
        "Angelic", "Trifid", "Mutative", "Silent", "Golden", "Crystal", "Phantom",
        "Frozen", "Blazing", "Hidden", "Ancient", "Modern", "Virtual", "Infinite",
        "Mystic", "Cosmic", "Radiant", "Neon", "Prism", "Stellar"
    ]
    
    private let nouns = [
        "Boating", "Cathouse", "Vocal", "Thunder", "Whisper", "Shadow", "Phoenix",
        "Dragon", "Storm", "Nexus", "Matrix", "Cipher", "Enigma", "Prism",
        "Vertex", "Pulse", "Echo", "Flux", "Zen", "Aura"
    ]
    
    private let colors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .red, .cyan, .mint, .indigo, .teal
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
                    ForEach(Array(codenames.enumerated()), id: \.element.id) { index, codename in
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

// MARK: - Header View
struct HeaderView: View {
    // State to control the tooltip popover visibility
    @State private var showTooltip = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Find your Codename")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                // Tooltip icon that shows a popover when tapped
                Button(action: {
                    showTooltip.toggle()
                }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .popover(isPresented: $showTooltip, arrowEdge: .top) {
                    Text("Codenames are generated on your computer by you. No servers or databases are involved at all. Your Codename is your personally owned anonymous identity shared across every Haven Chat you join. It is private and it can never be traced back to you.")
                        .font(.caption)
                        .padding(24)
                        .frame(width: UIScreen.screenWidth)
                        .fixedSize(horizontal: false, vertical: true)
                        // Adapts the popover size for a better fit on different devices
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
        .padding(6)
    }
}


// MARK: - Codename Card
struct CodenameCard: View {
    let codename: Codename
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Color accent bar
            RoundedRectangle(cornerRadius: 4)
                .fill(codename.color)
                .frame(width: 4, height: 48)
            
            // Codename text
            Text(codename.text)
                .font(.system(size: 17, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Spacer()
            
            // Selection indicator
            ZStack {
                Circle()
                    .stroke(isSelected ? codename.color : Color.secondary.opacity(0.3), lineWidth: 2)
                    .frame(width: 28, height: 28)
                
                if isSelected {
                    Circle()
                        .fill(codename.color)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? codename.color : Color.clear,
                            lineWidth: 2
                        )
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}

// MARK: - Bottom Actions
struct BottomActionsView: View {
    @Binding var isGenerating: Bool
    let selectedCodename: Codename?
    let onGenerate: () -> Void
    let onClaim: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Generate button
            Button(action: onGenerate) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .rotationEffect(.degrees(isGenerating ? 360 : 0))
                        .animation(
                            isGenerating ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                            value: isGenerating
                        )
                    
                    Text("Generate New Set")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.haven)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isGenerating)
            
            // Claim button
            Button(action: onClaim) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text("Claim Codename")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(selectedCodename != nil ? Color.haven : Color.secondary.opacity(0.3))
                .foregroundColor(selectedCodename != nil ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(selectedCodename == nil)
        }
    }
}

// MARK: - Previews
#Preview("Codename Generator") {
    CodenameGeneratorView()
}

#Preview("Dark Mode") {
    CodenameGeneratorView()
        .preferredColorScheme(.dark)
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

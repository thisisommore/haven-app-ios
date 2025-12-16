import SwiftData
import SwiftUI

struct LandingPage<T>: View where T: XXDKP {
    @State private var moveUp: Bool = false
    @State private var showProgress: Bool = false
    @EnvironmentObject var xxdk: T
    @EnvironmentObject private var swiftDataActor: SwiftDataActor
    @EnvironmentObject private var sm: SecretManager
    @Environment(\.navigation) var navigation
    @State private var isLoadingDone = false
    var body: some View {

        VStack(spacing: 12) {
            VStack(alignment: .leading) {
                Text("XXNetwork").bold().font(.system(size: 22, design: .serif))
                Text("Haven App.").multilineTextAlignment(.leading).font(
                    .system(size: 12, design: .serif)
                )
            }

            if showProgress && !isLoadingDone {
                HStack {
                    ProgressView(value: xxdk.statusPercentage, total: 100).tint(
                        .gray
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                   
                    .onChange(of: xxdk.statusPercentage) { _, newValue in
                        if newValue == 100 && !isLoadingDone {
                            isLoadingDone = true
                            // Clear path to reset stack for main app view (handled by isSetupComplete)
                            navigation.path = NavigationPath()
                        }
                    }
                }.frame(width: 120)

                Text(xxdk.status).font(.system(size: 12)).foregroundStyle(
                    .secondary
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.5), value: moveUp)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.9),
            value: showProgress
        )
        .task {
            // 1) Hide progress for 1s (your comment says 2s, code had 1s)
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            // 2) Move text up
            withAnimation(.easeInOut(duration: 2)) { moveUp = true }

            // 3) Slight delay, then reveal progress with a transition
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                showProgress = true
            }
        }
        .onChange(of: showProgress) { _, newValue in
             if newValue && xxdk.statusPercentage == 100 && !isLoadingDone {
                 isLoadingDone = true
                 // Clear path to reset stack for main app view
                 navigation.path = NavigationPath()
             }
        }

    }
}

#Preview {
    let container = try! ModelContainer(
        for: ChatModelModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    ["Tom", "Mayur", "Shashank"].forEach { name in
        container.mainContext.insert(
            ChatModelModel(pubKey: name.data, name: name, dmToken: 0, color: greenColorInt)
        )
    }
    let actor = SwiftDataActor(previewModelContainer: container)
    return LandingPage<XXDKMock>().environmentObject(XXDKMock())
        .environmentObject(actor).modelContainer(container)
}

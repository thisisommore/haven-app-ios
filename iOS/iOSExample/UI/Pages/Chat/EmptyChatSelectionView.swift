import SwiftUI

struct EmptyChatSelectionView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("No Chat Selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview {
    EmptyChatSelectionView()
}

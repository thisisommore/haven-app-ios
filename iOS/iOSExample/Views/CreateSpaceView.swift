import SwiftUI

struct CreateSpaceView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var isSecret: Bool = true
    @State private var enableDirectMessages: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Space Details")) {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Privacy")) {
                    Toggle("Secret", isOn: $isSecret)
                }
                
                Section(footer: Text("Allow members to send direct messages to each other")) {
                    Toggle("Enable Direct Messages", isOn: $enableDirectMessages)
                }
            }
            .navigationTitle("Create Space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }.tint(.haven)
                }.hiddenSharedBackground()
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        // TODO: Handle creation
                    }
                    .tint(.haven)
                    .disabled(name.isEmpty)
                }.hiddenSharedBackground()
            }
        }
    }
}

#Preview {
    CreateSpaceView()
}


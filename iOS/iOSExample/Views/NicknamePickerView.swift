//
//  NicknamePickerView.swift
//  iOSExample
//

import SwiftUI

struct NicknamePickerView<T: XXDKP>: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var xxdk: T
    
    @State private var nickname: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    
    let codename: String
    
    private let maxNicknameLength = 24
    
    private var displayName: String {
        if nickname.isEmpty {
            return codename
        }
        let truncatedNick = nickname.count > 10 ? String(nickname.prefix(10)) + "…" : nickname
        return "\(truncatedNick) aka \(codename)"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    // Preview
                    nicknamePreview
                        .padding(.top, 8)
                    
                    // Nickname input
                    nicknameInput
                    
                    // Info text
                    infoSection
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("DM Nickname")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .tint(.haven)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveNickname() }
                        .fontWeight(.semibold)
                        .tint(.haven)
                        .disabled(isSaving)
                }
            }
            .onAppear { loadCurrentNickname() }
        }
    }
    
    // MARK: - Preview
    private var nicknamePreview: some View {
        VStack(spacing: 12) {
            Text("Preview")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .overlay {
                        ChatBackgroundView()
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .allowsHitTesting(false)
                    }
                
                VStack(spacing: 12) {
                    mockMessage("Hey there! 👋", sender: displayName, isFromYou: true)
                    mockMessage("Nice to meet you!", sender: "Alice", isFromYou: false)
                }
                .padding(20)
            }
            .frame(height: 160)
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        }
    }
    
    /// Shows message from receiver's perspective - your messages appear as incoming to them
    private func mockMessage(_ text: String, sender: String, isFromYou: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if !isFromYou { Spacer() }
            
            VStack(alignment: isFromYou ? .leading : .trailing, spacing: 4) {
                Text(sender)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isFromYou ? .haven : .secondary)
                
                Text(text)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isFromYou ? Color(.systemGray5) : Color.haven)
                    .foregroundColor(isFromYou ? .primary : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            if isFromYou { Spacer() }
        }
    }
    
    // MARK: - Nickname Input
    private var nicknameInput: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Nickname")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(nickname.count)/\(maxNicknameLength)")
                        .font(.caption)
                        .foregroundStyle(nickname.count > maxNicknameLength ? .red : .secondary)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "person.text.rectangle")
                        .foregroundColor(.haven)
                        .frame(width: 20)
                    TextField("Enter nickname", text: $nickname)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .onChange(of: nickname) { _, newValue in
                            if newValue.count > maxNicknameLength {
                                nickname = String(newValue.prefix(maxNicknameLength))
                            }
                        }
                    
                    if !nickname.isEmpty {
                        Button {
                            nickname = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.haven)
                        }
                    }
                }
                .padding()
                .background(Color.haven.opacity(0.08))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(nickname.isEmpty ? Color.clear : Color.haven, lineWidth: 1.5)
                )
            }
            
            if nickname.count > 10 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Nickname will be truncated to 10 chars in display")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
        )
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundStyle(.haven)
                Text("This nickname applies to Direct Messages only.")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.haven)
                Text("Your nickname is sent with every DM message. Recipients will see this instead of your codename.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Image(systemName: "number.square")
                    .foregroundStyle(.haven)
                Text("For channels, set your nickname in each channel's settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Image(systemName: "textformat.size")
                    .foregroundStyle(.haven)
                Text("Nicknames longer than 10 chars are truncated in display to prevent scams.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.haven)
                Text("Leave empty to use your codename.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
        )
    }
    
    // MARK: - Actions
    private func loadCurrentNickname() {
        do {
            let currentNickname = try xxdk.getDMNickname()
            nickname = currentNickname
        } catch {
            // No nickname set, leave empty
            nickname = ""
        }
    }
    
    private func saveNickname() {
        isSaving = true
        errorMessage = nil
        
        do {
            try xxdk.setDMNickname(nickname)
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
        
        isSaving = false
    }
}

#Preview {
    NicknamePickerView<XXDKMock>(codename: "juniorFunkyAntiquity")
        .environmentObject(XXDKMock())
}

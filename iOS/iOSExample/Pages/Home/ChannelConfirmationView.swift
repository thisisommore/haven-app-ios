//
//  ChannelConfirmationView.swift
//  iOSExample
//
//  Created by Om More on 08/10/25.
//

import SwiftUI

struct ChannelConfirmationView: View {
    let channelName: String
    let channelURL: String
    @Binding var isJoining: Bool
    let onConfirm: (Bool) -> Void

    @State private var enableDM = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Channel Details")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(channelName)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("URL")) {
                    Text(channelURL)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .textSelection(.enabled)
                }

                Section {
                    Toggle("Enable DM", isOn: $enableDM)
                        .tint(.haven)
                        .disabled(isJoining)
                }

                if isJoining {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(.circular)
                            Text("Joining channel...")
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Confirm Channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }.tint(.haven)
                        .disabled(isJoining)
                }.hiddenSharedBackground()
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        onConfirm(enableDM)
                    }.tint(.haven)
                        .disabled(isJoining)
                }.hiddenSharedBackground()
            }
        }
    }
}

#Preview {
    @Previewable @State var isJoining = false
    return ChannelConfirmationView(
        channelName: "xx Network General",
        channelURL: "http://haven.xx.network/join?0Name=xxGeneralChat&1Description=Talking+about+the+xx+network&2Level=Public&3Created=1674152234202224215&e=%2FqE8BEgQQkXC6n0yxeXGQjvyklaRH6Z%2BWu8qvbFxiuw%3D&k=RMfN%2B9pD%2FJCzPTIzPk%2Bpf0ThKPvI425hye4JqUxi3iA%3D&l=368&m=0&p=1&s=rb%2BrK0HsOYcPpTF6KkpuDWxh7scZbj74kVMHuwhgUR0%3D&v=1",
        isJoining: $isJoining,
        onConfirm: { _ in
        }
    )
}

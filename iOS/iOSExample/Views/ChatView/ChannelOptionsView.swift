//
//  ChannelOptionsView.swift
//  iOSExample
//
//  Created by Om More
//

import SwiftUI
import SwiftData

struct ChannelOptionsView<T: XXDKP>: View {
    let chat: Chat?
    let onLeaveChannel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var xxdk: T
    @State private var isDMEnabled: Bool = false
    @State private var shareURL: String?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Channel Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(chat?.name ?? "Unknown")
                            .font(.body)
                    }
                    
                    if let description = chat?.channelDescription, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(description)
                                .font(.body)
                        }
                    }
                    
                    Toggle("Direct Messages", isOn: $isDMEnabled)
                        .onChange(of: isDMEnabled) { oldValue, newValue in
                            guard let channelId = chat?.id else { return }
                            do {
                                if newValue {
                                    try xxdk.enableDirectMessages(channelId: channelId)
                                } else {
                                    try xxdk.disableDirectMessages(channelId: channelId)
                                }
                            } catch {
                                print("Failed to toggle DM: \(error)")
                                isDMEnabled = oldValue
                            }
                        }
                    
                    if let urlString = shareURL, let url = URL(string: urlString) {
                        ShareLink(item: url) {
                            HStack {
                                Text(verbatim: urlString)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .tint(.haven)
                    }
                }
                .onAppear {
                    guard let channelId = chat?.id else { return }
                    do {
                        isDMEnabled = try xxdk.areDMsEnabled(channelId: channelId)
                    } catch {
                        print("Failed to fetch DM status: \(error)")
                        isDMEnabled = false
                    }
                    do {
                        shareURL = try xxdk.getShareURL(channelId: channelId, host: "https://xxnetwork.com/join")
                        print("Share URL: \(shareURL ?? "nil")")
                    } catch {
                        print("Failed to fetch share URL: \(error)")
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        onLeaveChannel()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Leave Channel")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Channel Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }.tint(.haven)
                }.hiddenSharedBackground()
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Chat.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let mockChat = Chat(
        channelId: "mock-channel-123",
        name: "General Discussion",
        description: "A channel for general team discussions and announcements",
    )
    container.mainContext.insert(mockChat)
    
    return ChannelOptionsView<XXDKMock>(chat: mockChat) {
        print("Leave channel tapped")
    }
    .modelContainer(container)
    .environmentObject(XXDKMock())
}

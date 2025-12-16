//
//  MessageForm.swift
//  iOSExample
//
//  Created by Om More on 28/09/25.
//
import SwiftData
import SwiftUI

extension View {
    @ViewBuilder
    func glassEffectIfAvailable() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(in: .rect(cornerRadius: 0))
        } else {
            self
        }
    }
}

struct MessageForm<T: XXDKP>: View {
    @State private var abc: String = ""
    @State private var isSendingMessage: Bool = false
    var chat: ChatModel?
    var replyTo: ChatMessageModel?
    var onCancelReply: (() -> Void)?
    @EnvironmentObject private var xxdk: T
    @State private var showSendButton: Bool = false
    @Namespace private var namespace

    // File transfer state
    @StateObject private var fileTransferManager = FileTransferManager()
    @State private var showFilePicker: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Upload progress overlay
            if case .uploading = fileTransferManager.state {
                UploadProgressOverlay(state: fileTransferManager.state) {
                    fileTransferManager.cancel(xxdk: xxdk)
                }
                .padding(.bottom, 8)
            } else if case .failed = fileTransferManager.state {
                UploadProgressOverlay(state: fileTransferManager.state) {
                    fileTransferManager.reset()
                }
                .padding(.bottom, 8)
            } else if case .completed = fileTransferManager.state {
                UploadProgressOverlay(state: fileTransferManager.state) {
                    fileTransferManager.reset()
                }
                .padding(.bottom, 8)
            }

            // Selected file preview
            if let fileName = fileTransferManager.selectedFileName,
               let fileData = fileTransferManager.selectedFileData,
               case .idle = fileTransferManager.state
            {
                SelectedFilePreview(
                    fileName: fileName,
                    fileSize: fileData.count,
                    onRemove: { fileTransferManager.reset() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Reply preview
            if let replyTo = replyTo {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Replying to \(replyTo.sender?.codename ?? "You")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HTMLText(
                            replyTo.message,
                            textColor: .black,
                            linkColor: .blue,
                            lineLimit: 3
                        )
                        .fontSize(13)
                    }
                    Spacer()
                    Button {
                        onCancelReply?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.haven)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 8) {
                // File attachment button (only for channels, not DMs)
                if chat?.dmToken == nil {
                    FileAttachmentButton(showFilePicker: $showFilePicker)
                }

                TextField(
                    "",
                    text: $abc,
                    axis: .vertical
                ).lineLimit(1 ... 10)
                    .onSubmit {
                        sendMessage()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 18)
                    .background(.formBG.opacity(0.1))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 40))
                    .padding(.trailing, 8)

                if fileTransferManager.selectedFileData != nil && abc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Send file button
                    Button(action: sendFile) {
                        Image(systemName: "arrow.up.doc.fill")
                            .padding(.vertical, 4)
                    }.tint(.haven)
                        .buttonStyle(.borderedProminent)
                        .padding(.trailing, 6)
                        .buttonBorderShape(.circle)
                        .transition(.scale.combined(with: .opacity))
                } else if !abc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !isSendingMessage
                {
                    Button(action: sendMessage) {
                        Image(systemName: "chevron.right")
                            .padding(.vertical, 4)
                    }.tint(.haven)
                        .buttonStyle(.borderedProminent)
                        .padding(.trailing, 6)
                        .buttonBorderShape(.circle)
                        .transition(.scale.combined(with: .opacity))
                }
                if isSendingMessage {
                    Spacer()
                    ProgressView()
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.7),
                value: abc.isEmpty
            )
            .animation(
                .spring(response: 0.3, dampingFraction: 0.7),
                value: fileTransferManager.selectedFileName
            )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: replyTo?.id)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: fileTransferManager.state)
        .background(.bottomNav).background(.ultraThinMaterial)
        .sheet(isPresented: $showFilePicker) {
            FilePickerSheet(isPresented: $showFilePicker, manager: fileTransferManager)
        }
    }

    private func sendMessage() {
        // Guard against double-submission
        guard !isSendingMessage else { return }
        let trimmed = abc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation {
            isSendingMessage = true
        }

        if let chat = chat {
            if let token = chat.dmToken {
                // DM chat: send direct message or reply
                if let pubKey = Data(base64Encoded: chat.id) {
                    if let replyTo = replyTo {
                        Task {
                            xxdk.sendReply(
                                msg: trimmed,
                                toPubKey: pubKey,
                                partnerToken: token,
                                replyToMessageIdB64: replyTo.id
                            )
                        }
                    } else {
                        Task {
                            xxdk.sendDM(
                                msg: trimmed,
                                toPubKey: pubKey,
                                partnerToken: token
                            )
                        }
                    }
                }
            } else {
                // Channel chat: send via Channels Manager using channelId (stored in id)
                if let replyTo = replyTo {
                    Task {
                        xxdk.sendReply(
                            msg: trimmed,
                            channelId: chat.id,
                            replyToMessageIdB64: replyTo.id
                        )
                    }
                } else {
                    Task {
                        xxdk.sendDM(
                            msg: trimmed,
                            channelId: chat.id
                        )
                    }
                }
            }
        }
        withAnimation {
            isSendingMessage = false
        }
        abc = ""
        onCancelReply?()
    }

    private func sendFile() {
        guard let chat = chat, chat.dmToken == nil else { return }
        fileTransferManager.uploadAndSend(xxdk: xxdk, channelId: chat.id)
    }
}

#Preview {
    // In-memory SwiftData container for previewing MessageForm
    let container = try! ModelContainer(
        for: ChatModel.self,
        ChatMessageModel.self,
        MessageReactionModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    // Create a simple preview chat
    let previewChat = ChatModel(channelId: "previewChannelId", name: "Preview Chat")
    container.mainContext.insert(previewChat)
    return ZStack {
        Color(.appBackground).edgesIgnoringSafeArea(.all)
        VStack {
            Spacer()
            MessageForm<XXDKMock>(
                chat: previewChat,
                replyTo: nil,
                onCancelReply: {}
            )
            .modelContainer(container)
            .environmentObject(XXDKMock())
        }
    }
}

#Preview("Reply Mode") {
    // In-memory SwiftData container for previewing MessageForm with reply
    let container = try! ModelContainer(
        for: ChatModel.self,
        ChatMessageModel.self,
        MessageReactionModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    // Create a simple preview chat
    let previewChat = ChatModel(channelId: "previewChannelId", name: "Preview Chat")
    container.mainContext.insert(previewChat)

    // Create a message to reply to
    let messageToReplyTo = ChatMessageModel(
        message:
        "<p>Hey! Can you check out this <a href=\"https://example.com\">link</a>? It has some really interesting information about the project we discussed yesterday.</p>",
        isIncoming: true,
        chat: previewChat,
        sender: MessageSenderModel(
            id: "alice-id",
            pubkey: Data(),
            codename: "Alice",
            dmToken: 0,
            color: greenColorInt
        ),
        id: "msg-123",
        internalId: InternalIdGenerator.shared.next()
    )
    container.mainContext.insert(messageToReplyTo)

    return VStack {
        Spacer()
        MessageForm<XXDKMock>(
            chat: previewChat,
            replyTo: messageToReplyTo,
            onCancelReply: {
                print("Cancel reply tapped")
            }
        )
        .modelContainer(container)
        .environmentObject(XXDKMock())
    }.background(.appBackground)
}

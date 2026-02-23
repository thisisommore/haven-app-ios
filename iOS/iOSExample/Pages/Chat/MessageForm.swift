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

    var body: some View {
        VStack(spacing: 0) {
            // Reply preview
            if let replyTo {
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
                TextField(
                    "",
                    text: $abc,
                    axis: .vertical
                ).lineLimit(1 ... 10)
                    .onSubmit {
                        sendMessage()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.formBG.opacity(0.1))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 40))
                    .padding(.trailing, 8)

                if !abc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: replyTo?.id)
        .background(.bottomNav).background(.ultraThinMaterial)
    }

    private func sendMessage() {
        // Guard against double-submission
        guard !isSendingMessage else { return }
        let trimmed = abc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation {
            isSendingMessage = true
        }

        if let chat {
            if let token = chat.dmToken {
                // DM chat: send direct message or reply
                if let pubKey = Data(base64Encoded: chat.id) {
                    if let replyTo {
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
                if let replyTo {
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
}

#Preview {
    MessageFormPreviewWrapper()
        .mock()
}

#Preview("Reply Mode") {
    MessageFormPreviewWrapper(replyMode: true)
        .mock()
}

private struct MessageFormPreviewWrapper: View {
    @Query(filter: #Predicate<ChatModel> { $0.id == previewChatId }) private var chats: [ChatModel]
    @Query private var messages: [ChatMessageModel]
    var replyMode: Bool = false

    var body: some View {
        ZStack {
            Color.appBackground.edgesIgnoringSafeArea(.all)
            if let chat = chats.first {
                VStack {
                    Spacer()
                    MessageForm<XXDKMock>(
                        chat: chat,
                        replyTo: replyMode ? messages.first : nil,
                        onCancelReply: {}
                    )
                }
            }
        }
    }
}

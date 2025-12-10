//
//  FileMessageBubble.swift
//  iOSExample
//
//  File/image message display component
//

import SwiftUI

/// Bubble for displaying file attachments in chat
struct FileMessageBubble: View {
    let message: ChatMessage
    let isIncoming: Bool
    let timestamp: String
    let isHighlighted: Bool
    
    var body: some View {
        VStack(alignment: isIncoming ? .leading : .trailing, spacing: 4) {
            if isIncoming, let sender = message.sender {
                MessageSender(isIncoming: isIncoming, sender: sender)
            }
            
            // File content
            if message.isImage {
                imageContent
            } else {
                fileContent
            }
            
            // Timestamp
            Text(timestamp)
                .font(.system(size: 10))
                .foregroundStyle(isIncoming ? Color.messageText : Color.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(isIncoming ? Color.messageBubble : Color.haven)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: isIncoming ? 0 : 16,
                bottomTrailingRadius: isIncoming ? 16 : 0,
                topTrailingRadius: 16
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: isIncoming ? 0 : 16,
                bottomTrailingRadius: isIncoming ? 16 : 0,
                topTrailingRadius: 16
            )
            .stroke(Color.haven, lineWidth: isHighlighted ? 2 : 0)
        )
        .shadow(color: Color.haven.opacity(isHighlighted ? 0.5 : 0), radius: 8)
        .animation(.easeInOut(duration: 0.25), value: isHighlighted)
        .padding(.top, 6)
    }
    
    @ViewBuilder
    private var imageContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageData = message.fileData ?? message.filePreview,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 250, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Placeholder for image not yet downloaded
                imagePlaceholder
            }
            
            if let fileName = message.fileName {
                Text(fileName)
                    .font(.caption)
                    .foregroundStyle(isIncoming ? Color.messageText.opacity(0.7) : Color.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }
    
    @ViewBuilder
    private var imagePlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 200, height: 150)
            
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(Color.gray)
                Text("Image")
                    .font(.caption)
                    .foregroundStyle(Color.gray)
            }
        }
    }
    
    @ViewBuilder
    private var fileContent: some View {
        HStack(spacing: 12) {
            // File icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isIncoming ? Color.haven.opacity(0.15) : Color.white.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: fileIcon)
                    .font(.title2)
                    .foregroundStyle(isIncoming ? Color.haven : Color.white)
            }
            
            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(message.fileName ?? "File")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isIncoming ? Color.messageText : Color.white)
                    .lineLimit(2)
                
                HStack(spacing: 4) {
                    Text(message.fileType?.uppercased() ?? "FILE")
                        .font(.caption2.weight(.medium))
                    
                    if let data = message.fileData {
                        Text("•")
                        Text(formatFileSize(data.count))
                            .font(.caption2)
                    }
                }
                .foregroundStyle(isIncoming ? Color.messageText.opacity(0.6) : Color.white.opacity(0.7))
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 250)
    }
    
    private var fileIcon: String {
        guard let type = message.fileType?.lowercased() else { return "doc.fill" }
        
        switch type {
        case "pdf":
            return "doc.text.fill"
        case "doc", "docx":
            return "doc.richtext.fill"
        case "xls", "xlsx":
            return "tablecells.fill"
        case "ppt", "pptx":
            return "rectangle.stack.fill"
        case "zip", "rar", "7z":
            return "archivebox.fill"
        case "mp3", "wav", "m4a":
            return "music.note"
        case "mp4", "mov", "avi":
            return "video.fill"
        default:
            return "doc.fill"
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // Image message incoming
        let imageMsg = ChatMessage(
            message: "📎 photo.jpg",
            isIncoming: true,
            chat: Chat(channelId: "test", name: "Test"),
            sender: Sender(id: "1", pubkey: Data(), codename: "Alice", dmToken: 0, color: 0x2196F3),
            id: "1",
            internalId: 1
        )
        
        FileMessageBubble(
            message: imageMsg,
            isIncoming: true,
            timestamp: "10:30 AM",
            isHighlighted: false
        )
        
        // File message outgoing
        let fileMsg = ChatMessage(
            message: "📎 document.pdf",
            isIncoming: false,
            chat: Chat(channelId: "test", name: "Test"),
            id: "2",
            internalId: 2
        )
        
        FileMessageBubble(
            message: fileMsg,
            isIncoming: false,
            timestamp: "10:31 AM",
            isHighlighted: false
        )
    }
    .padding()
}




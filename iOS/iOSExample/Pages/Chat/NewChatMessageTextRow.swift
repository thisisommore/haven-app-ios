import SwiftUI

struct NewChatMessageTextRow: View {
    let message: ChatMessageModel

    var body: some View {
        Text(verbatim: message.message)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

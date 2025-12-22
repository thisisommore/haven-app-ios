//
//  PreviewUtils.swift
//  iOSExample
//
//  Created by Om More on 22/12/25.
//

import SwiftUI
import Foundation
import SwiftData

#if DEBUG
extension View {
    func mock() -> some View {
        let container: ModelContainer = {
            let c = try! ModelContainer(
                for: ChatModel.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            for name in ["<self>", "Tom", "Mayur", "Shashank"] {
                let chat = ChatModel(pubKey: name.data, name: name, dmToken: 0, color: greenColorInt)
                c.mainContext.insert(chat)
                c.mainContext.insert(
                    ChatMessageModel(
                        message: "<p>Hello world</p>",
                        isIncoming: true,
                        chat: chat,
                        sender: nil,
                        id: name,
                        internalId: InternalIdGenerator.shared.next(),
                        replyTo: nil,
                        timestamp: 1
                    )
                )
            }
            try! c.mainContext.save()
            return c
        }()
        
        return self
            .modelContainer(container)
            .environmentObject(XXDKMock())
            .environmentObject(SelectedChat())
            .navigationBarBackButtonHidden()
    }
}
#endif


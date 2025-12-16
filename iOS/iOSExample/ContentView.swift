//
//  ContentView.swift
//  iOS Example
//
//  Created by Richard Carback on 2/29/24.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var SendMessageTextInput: String = ""
    @EnvironmentObject var xxdk: XXDK
    @EnvironmentObject var logOutput: LogViewer
    @Environment(\.modelContext) private var modelContext
    @State var showAlert = false
    var body: some View {
        VStack {
            ViewThatFits {
                ScrollView {
                    ForEach(logOutput.Messages) { line in
                        Text(line.Msg)
                    }
                }.defaultScrollAnchor(.bottom)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .border(.primary)
            ViewThatFits {
                ScrollView {
                    Text("Messages for " + (xxdk.codename ?? "Unknown"))
                    ForEach(xxdk.dmReceiver.msgBuf) { msg in
                        Text(msg.Msg)
                    }
                }.defaultScrollAnchor(.bottom)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .border(.primary)
            HStack(alignment: .bottom) {
                TextField(
                    "Enter Message to Send",
                    text: $SendMessageTextInput
                )
                .onKeyPress(
                    .return,
                    action: {
                        guard xxdk.cmix?.readyToSend() == true else {
                            return KeyPress.Result.handled
                        }
                        if let key = xxdk.DM?.getPublicKey() {
                            xxdk.sendDM(
                                msg: SendMessageTextInput, toPubKey: key,
                                partnerToken: Int32(xxdk.DM?.getToken() ?? 0)
                            )
                        }
                        SendMessageTextInput = ""
                        return KeyPress.Result.handled
                    }
                )
                .textFieldStyle(.roundedBorder)
                Button(
                    action: {
                        guard xxdk.cmix?.readyToSend() == true else { return }
                        if let key = xxdk.DM?.getPublicKey() {
                            xxdk.sendDM(
                                msg: SendMessageTextInput, toPubKey: key,
                                partnerToken: Int32(xxdk.DM?.getToken() ?? 0)
                            )
                        }
                        SendMessageTextInput = ""
                    },
                    label: {
                        Text("Send")
                    }
                ).alert(
                    isPresented: $showAlert,
                    content: {
                        Alert(
                            title: Text("The network is getting ready, please try again shortly."))
                    }
                )
                .buttonStyle(.borderedProminent)
            }.padding()
        }.padding()
            .onAppear(perform: {
                // SwiftDataActor is now injected via LandingPage.swift and passed to XXDK
                Task {
                    await xxdk.load()
                }
            })
    }
}

#Preview {
    ContentView().environmentObject(XXDKMock()).environmentObject(LogViewer())
        .modelContainer(for: Item.self, inMemory: true)
}

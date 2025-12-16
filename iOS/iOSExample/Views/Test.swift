//
//  Test.swift
//  iOSExample
//
//  Created by Om More on 19/10/25.
//

import SwiftUI

struct TestV: View {
    var body: some View {
        VStack(alignment: .leading) {
            // title
            Text("Example")
                .font(.title3)
                .fontWeight(.bold)
            Text("This is an example how to implement the flexible view into our view")

            // NEW: Direct ViewBuilder syntax
            FlexibleView(availableWidth: 300) {
                Rectangle()
                    .fill(.red)
                    .frame(width: 40, height: 40)

                Rectangle()
                    .fill(.blue)
                    .frame(width: 60, height: 40)

                Rectangle()
                    .fill(.green)
                    .frame(width: 80, height: 40)

                Rectangle()
                    .fill(.orange)
                    .frame(width: 50, height: 40)

                Rectangle()
                    .fill(.purple)
                    .frame(width: 70, height: 40)

                ForEach(0 ..< 5) { _ in
                    Rectangle()
                        .fill(.pink)
                        .frame(width: 45, height: 40)
                }
            }

            Divider()
                .padding(.vertical)

            // OLD: Using helper function (still works)
            FlexibleView(
                availableWidth: 300,
                content: renderSomeBox
            )
        }
        .frame(width: 300)
    }

    // function to render some boxes into the flexibleView
    @ViewBuilder
    func renderSomeBox() -> some View {
        ForEach(0 ..< 10, id: \.self) { _ in
            Rectangle()
                .fill(.cyan)
                .frame(width: 40, height: 40)
        }
    }
}

#Preview("flex") {
    TestV()
}

import WebKit

struct HTMLStringView: UIViewRepresentable {
    let htmlContent: String

    func makeUIView(context _: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context _: Context) {
        uiView.loadHTMLString(htmlContent, baseURL: nil)
    }
}

struct Test: View {
    var body: some View {
        VStack {
            Text("Testing HTML Content")
            Spacer()
            HTMLStringView(htmlContent: "<h1>This is HTML String</h1>")
            Spacer()
        }
    }
}

#Preview("html") {
    Test()
}

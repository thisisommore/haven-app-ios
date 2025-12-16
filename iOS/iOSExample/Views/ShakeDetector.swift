//
//  ShakeDetector.swift
//  iOSExample
//

import SwiftUI
import UIKit


extension UIDevice {
    static let shakeNotification = Notification.Name("deviceDidShake")
}


extension UIWindow {
    override open func motionEnded(_ motion: UIEvent.EventSubtype, with _: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.shakeNotification, object: nil)
        }
    }
}


struct ShakeDetectorModifier: ViewModifier {
    let onShake: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.shakeNotification)) { _ in
                onShake()
            }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(ShakeDetectorModifier(onShake: action))
    }
}


struct LogViewerShakeModifier: ViewModifier {
    @State private var showLogViewerAlert = false
    @State private var showLogViewerSheet = false

    func body(content: Content) -> some View {
        content
            .onShake {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                showLogViewerAlert = true
            }
            .alert("Developer Console", isPresented: $showLogViewerAlert) {
                Button("Open Log Viewer") {
                    showLogViewerSheet = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Do you want to open the log viewer?")
            }
            .sheet(isPresented: $showLogViewerSheet) {
                LogViewerSheet()
            }
    }
}


struct LogViewerSheet: View {
    var body: some View {
        LogViewerUI()
            .presentationDetents([.fraction(0.75), .large])
            .presentationDragIndicator(.visible)
    }
}

extension View {
    func logViewerOnShake() -> some View {
        modifier(LogViewerShakeModifier())
    }
}

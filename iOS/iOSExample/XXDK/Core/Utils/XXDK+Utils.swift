//
//  XXDK+Utils.swift
//  iOSExample
//

import Foundation
import SwiftUI

extension XXDK {
    public func progress(_ status: XXDKProgressStatus) async {
        await MainActor.run {
            withAnimation {
                self.status = status.message

                if status.increment == -1 {
                    self.statusPercentage = 100.0
                    Self.playCompletionHaptic()
                } else {
                    let _statusPercentage = min(self.statusPercentage + status.increment, 100.0)
                    if _statusPercentage == 100.0, self.statusPercentage < 100.0 {
                        Self.playCompletionHaptic()
                    }
                    self.statusPercentage = _statusPercentage
                }
            }
        }
    }

    /// Plays a subtle, satisfying haptic pattern for completion events
    static func playCompletionHaptic() {
        let soft = UIImpactFeedbackGenerator(style: .soft)
        let notif = UINotificationFeedbackGenerator()

        soft.prepare()
        notif.prepare()

        soft.impactOccurred(intensity: 0.4)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            notif.notificationOccurred(.success)
        }
    }

    func lockTask() {
        nsLock.lock()
    }

    func unlockTask() {
        nsLock.unlock()
    }
}


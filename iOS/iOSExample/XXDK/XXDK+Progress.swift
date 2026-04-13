//
//  XXDK+Progress.swift
//  iOSExample
//

import Foundation
import SwiftUI

enum XXDKProgressStatus {
  case none
  case downloadingNDF
  case settingUpCmix
  case loadingCmix
  case startingNetworkFollower
  case loadingIdentity
  case creatingIdentity
  case syncingNotifications
  case settingUpRemoteKV
  case preparingChannelsManager
  case joiningChannels

  var message: String {
    switch self {
    case .none:
      return ""
    case .downloadingNDF:
      return "Downloading NDF"
    case .settingUpCmix:
      return "Setting up cMixx"
    case .loadingCmix:
      return "Loading cMixx"
    case .startingNetworkFollower:
      return "Starting network follower"
    case .loadingIdentity:
      return "Loading identity"
    case .creatingIdentity:
      return "Creating your identity"
    case .syncingNotifications:
      return "Syncing notifications"
    case .settingUpRemoteKV:
      return "Setting up remote KV"
    case .preparingChannelsManager:
      return "Preparing channels manager"
    case .joiningChannels:
      return "Joining xxGeneralChat"
    }
  }
}

extension XXDK {
  func progress(_ status: XXDKProgressStatus) async {
    await MainActor.run {
      withAnimation {
        self.status = status
      }
    }
  }

  /// Plays a subtle, satisfying haptic pattern for completion events
  private static func playCompletionHaptic() {
    let soft = UIImpactFeedbackGenerator(style: .soft)
    let notif = UINotificationFeedbackGenerator()

    soft.prepare()
    notif.prepare()

    soft.impactOccurred(intensity: 0.4)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
      notif.notificationOccurred(.success)
    }
  }
}

//
//  Progress.swift
//  iOSExample
//
//  Created by Om More on 20/10/25.
//

// Add this enum before the XXDK class definition
enum XXDKProgressStatus {
    case downloadingNDF
    case settingUpCmix
    case loadingCmix
    case startingNetworkFollower
    case loadingIdentity
    case creatingIdentity
    case syncingNotifications
    case connectingToNodes
    case settingUpRemoteKV
    case waitingForNetwork
    case preparingChannelsManager
    case joiningChannels
    case readyExistingUser
    case networkFollowerComplete
    case ready
    case final // Edge case: force 100% completion

    var message: String {
        switch self {
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
        case .connectingToNodes:
            return "Connecting to nodes"
        case .settingUpRemoteKV:
            return "Setting up remote KV"
        case .waitingForNetwork:
            return "Waiting for network to be ready"
        case .preparingChannelsManager:
            return "Preparing channels manager"
        case .joiningChannels:
            return "Joining xxGeneralChat"
        case .networkFollowerComplete:
            return "Network follower complete"
        case .ready:
            return "Ready"
        case .readyExistingUser:
            return "Preparing"
        case .final:
            return "Complete"
        }
    }

    // Each step increments by 7% (13 steps × 7% = 91%, last step = 9% to reach 100%)
    var increment: Double {
        switch self {
        case .downloadingNDF:
            return 7
        case .settingUpCmix:
            return 7
        case .loadingCmix:
            return 7
        case .startingNetworkFollower:
            return 7
        case .loadingIdentity:
            return 7
        case .creatingIdentity:
            return 7
        case .syncingNotifications:
            return 7
        case .connectingToNodes:
            return 7
        case .settingUpRemoteKV:
            return 7
        case .waitingForNetwork:
            return 7
        case .preparingChannelsManager:
            return 7
        case .joiningChannels:
            return 7
        case .networkFollowerComplete:
            return 7
        case .ready:
            return -1 // Final step brings us to 100%
        case .readyExistingUser:
            return 9 + XXDKProgressStatus.joiningChannels.increment + XXDKProgressStatus.creatingIdentity.increment + XXDKProgressStatus.downloadingNDF.increment // Final step brings us to 100%
        case .final:
            return -1 // Special flag: force to 100%
        }
    }
}

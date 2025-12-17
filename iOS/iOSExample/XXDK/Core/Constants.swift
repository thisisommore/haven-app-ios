//
//  Constants.swift
//  iOSExample
//

import Foundation

// NDF is the configuration file used to connect to the xx network. It
// is a list of known hosts and nodes on the network.
// A new list is downloaded on the first connection to the network
public var MAINNET_URL =
    "https://elixxir-bins.s3.us-west-1.amazonaws.com/ndf/mainnet.json"

let XX_GENERAL_CHAT =
    "<Speakeasy-v3:xxGeneralChat|description:Talking about the xx network|level:Public|created:1674152234202224215|secrets:rb+rK0HsOYcPpTF6KkpuDWxh7scZbj74kVMHuwhgUR0=|RMfN+9pD/JCzPTIzPk+pf0ThKPvI425hye4JqUxi3iA=|368|1|/qE8BEgQQkXC6n0yxeXGQjvyklaRH6Z+Wu8qvbFxiuw=>"

// This resolves to "Resources/mainnet.crt" in the project folder for iOSExample
public var MAINNET_CERT =
    Bundle.main.path(forResource: "mainnet", ofType: "crt")
        ?? "unknown resource path"

enum MyError: Error {
    case runtimeError(String)
}


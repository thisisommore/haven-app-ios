//
//  Constants.swift
//  iOSExample
//

import Bindings
import Foundation

// NDF is the configuration file used to connect to the xx network. It
// is a list of known hosts and nodes on the network.
// A new list is downloaded on the first connection to the network
public var MAINNET_URL =
    "https://elixxir-bins.s3.us-west-1.amazonaws.com/ndf/mainnet.json"

let XX_IOS_CHAT =
    "https://xxnetwork.com/join?0Name=xxIOS&1Description=IOS+Testing+and+Feedback&2Level=Public&3Created=1771592853517873670&e=RvyvA08yZ%2BfSze8Z9HcWyrpqJmaocFM%2Fg5apiK9Dxlg%3D&k=3ScI2jqRkGUkm3cvLOPj30TvkodOQ3Gbqk%2F6s4vPgJs%3D&l=368&m=0&p=1&s=nwZ5OW4FSHieQPD3a27SB2hhNM15ZStRmT4wRdeotu4%3D&v=1"

// This resolves to "Resources/mainnet.crt" in the project folder for iOSExample
public var MAINNET_CERT =
    Bundle.main.path(forResource: "mainnet", ofType: "crt")
        ?? "unknown resource path"

enum MyError: Error {
    case runtimeError(String)
}

// MARK: - Modern Swift Error Types

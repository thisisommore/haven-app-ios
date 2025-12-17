//
//  NetTime.swift
//  iOSExample
//
//  Created by Om More on 24/09/25.
//
import Bindings
import Kronos

class NetTime: NSObject, Bindings.BindingsTimeSourceProtocol {
    override init() {
        super.init()
        Kronos.Clock.sync()
    }

    func nowMs() -> Int64 {
        let curTime = Kronos.Clock.now
        if curTime == nil {
            Kronos.Clock.sync()
            return Int64(Date.now.timeIntervalSince1970)
        }
        guard let nowTime = Kronos.Clock.now else {
            fatalError("Kronos.Clock.now is possibly nil")
        }
        return Int64(nowTime.timeIntervalSince1970)
    }
}

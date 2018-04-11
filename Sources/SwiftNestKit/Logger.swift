//
//  Logger.swift
//  SwiftNest
//
//  Created by Carl Chen on 2018/4/11.
//

import Foundation

struct Logger {
    static func error(_ msg: String) {
        NSLog("SwiftNestKit[error]: " + msg)
    }

    static func info(_ msg: String) {
        NSLog("SwiftNestKit[info]: " + msg)
    }
}

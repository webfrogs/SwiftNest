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

    static func debug(_ msg: String) {
#if DEBUG
        NSLog("SwiftNestKit[debug]: " + msg)
#endif
    }

    static func logCurrentMethodIfCalled(_ filePath: String = #file
        , method: String = #function
        , line: Int = #line) {

        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        debug("Method called:\n\(fileName)[\(line)], \(method) ")
    }
}

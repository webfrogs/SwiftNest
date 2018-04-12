//
//  RpcNotification.swift
//  SwiftNest
//
//  Created by Carl Chen on 2018/4/12.
//

import Foundation

struct RpcNotification {
    enum Method: String {
        case initialized
        case workspaceDidChangeConfig = "workspace/didChangeConfiguration"
    }
}

extension RpcNotification {
    static func handleNotification(method: Method, params: Any?) {
        switch method {
        case .initialized:
            Logger.info("Received \(method.rawValue) notification.")
        default:
            Logger.info("Nothing happens with this notification \(method.rawValue)")
        }
    }
}

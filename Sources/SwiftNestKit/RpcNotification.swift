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
        case exit
        case workspaceDidChangeConfig = "workspace/didChangeConfiguration"
    }
}

extension RpcNotification {
    static func handleNotification(method: Method, params: Any?) {
        switch method {
        case .exit:
            Logger.info("Exit.")
            exit(0)
        default:
            Logger.debug("Nothing happens with this notification \(method.rawValue)")
        }
    }
}

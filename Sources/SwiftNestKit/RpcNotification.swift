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
        case textDocumentDidOpen = "textDocument/didOpen"
        case textDocumentDidChange = "textDocument/didChange"
        case textDocumentDidClose = "textDocument/didClose"
    }

    private var _fileCache: [String: String] = [:]
}

extension RpcNotification {
    static func handleNotification(method: Method, params: Any?) {
        switch method {
        case .exit:
            Logger.info("Exit.")
            exit(0)
        case .textDocumentDidOpen:
            guard let fileInfo = params as? [String: Any] else {
                Logger.error("notification \(method.rawValue), params wrong")
                return
            }
            guard let uri: String = fileInfo.value(keyPath: "textDocument.uri")
                , let text: String = fileInfo.value(keyPath: "textDocument.text") else {
                    Logger.error("notification \(method.rawValue), params wrong")
                    return
            }

            SourceFileManager.manager.fileDidOpen(uri: uri, text: text)

        case .textDocumentDidChange:
            guard let fileInfo = params as? [String: Any] else {
                Logger.error("notification \(method.rawValue), params wrong")
                return
            }
            guard let uri: String = fileInfo.value(keyPath: "textDocument.uri")
                , let text: String = fileInfo.value(keyPath: "textDocument.text") else {
                    Logger.error("notification \(method.rawValue), params wrong")
                    return
            }

            SourceFileManager.manager.fileDidChange(uri: uri, text: text)
        case .textDocumentDidClose:
            guard let fileInfo = params as? [String: Any] else {
                Logger.error("notification \(method.rawValue), params wrong")
                return
            }
            guard let uri: String = fileInfo.value(keyPath: "textDocument.uri") else {
                    Logger.error("notification \(method.rawValue), params wrong")
                    return
            }
            SourceFileManager.manager.fileDidClose(uri: uri)
        default:
            Logger.debug("Nothing happens with this notification \(method.rawValue)")
        }
    }
}

//
//  HandleRequestMessage.swift
//  SwiftNest
//
//  Created by Carl Chen on 2018/4/12.
//

import Foundation

extension RequestMethod {
    func getHandler() -> MethodHandler {
        switch self {
        case .initialize:
            return RequestMethod.handleInitialize
        case .textDocHover:
            return RequestMethod.handleTextDocHover
        default:
            // done nothing
            return { (msg: RequestMessageProtocol) -> MethodResultProtocol? in return nil }
        }
    }
}

extension RequestMethod {
    static func handleInitialize(msg: RequestMessageProtocol) throws -> MethodResultProtocol? {
        guard let _ = msg.params as? [String: Any] else {
            throw ResponseError.internalError
        }

        let completionMap: [String: Any] = [
            "resolveProvider": true,
            "triggerCharacters": ["."],
            ]

        let capabilityMap: [String: Any] = [
//        "hoverProvider": true,
            "completionProvider": completionMap
        ]

        let result: [String: Any] = [
            "capabilities": capabilityMap
        ]

        return result
    }

    static func handleTextDocHover(msg: RequestMessageProtocol) throws -> MethodResultProtocol? {
        guard let params = msg.params as? [String: Any] else {
            throw ResponseError.internalError
        }

        guard let fileURI: String = params.value(keyPath: "textDocument.uri")
            , let line: Int = params.value(keyPath: "position.line")
            , let character: Int = params.value(keyPath: "position.character")
            else {
                throw RpcErrorCode.invalidParams.toResponseError(msgID: msg.id)
        }

        let file = URL(string: fileURI)
        Logger.info(file?.path ?? "")


        return nil
    }
}

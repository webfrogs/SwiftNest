//
//  CompletionHandler.swift
//  SwiftNest
//
//  Created by Carl Chen on 2018/4/13.
//

import Foundation

extension RequestMethod {
    static func textCompletion(msg: RequestMessageProtocol) throws -> MethodResultProtocol? {
        guard let params = msg.params as? [String: Any] else {
            throw ResponseError.internalError
        }

        guard let fileURI: String = params.value(keyPath: "textDocument.uri")
            , let line: Int = params.value(keyPath: "position.line")
            , let character: Int = params.value(keyPath: "position.character")
            else {
                throw RpcErrorCode.invalidParams.toResponseError(msgID: msg.id)
        }

        guard let fileData = SourceFileManager.manager.fileContentFrom(uri: fileURI)
            .flatMap({$0.data(using: String.Encoding.utf8)}) else {
                Logger.error("Can not find file from cache.")
                throw RpcErrorCode.internalError.toResponseError(msgID: msg.id)
        }

        let newlineChar = "\n".data(using: .utf8)!

        var currentOffset: UInt64 = 0
        var currentLine = 0
        var searchStartIndex = fileData.startIndex
        while true {
            if currentLine == line {
                currentOffset += UInt64(character)
                break
            }

            guard let newlineRange = fileData
                .range(of: newlineChar, options: [], in: searchStartIndex..<fileData.endIndex)
                else {
                    break
            }

            currentOffset += UInt64(newlineRange.lowerBound - searchStartIndex + 1)
            searchStartIndex = newlineRange.lowerBound.advanced(by: newlineChar.count)
            currentLine += 1
        }



        let demoItem: [String: Any] = [
            "label": "label",
            "kind": 3,
            "detail": "detail",
            "documentation": "documentation",
            "sortText": "sortText",
            ]

        let result: [String: Any] = [
            "isIncomplete": false,
            "items": [demoItem]
        ]

        return result
    }
}

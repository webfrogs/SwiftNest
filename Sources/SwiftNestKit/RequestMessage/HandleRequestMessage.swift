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
        case .textDocCompletion:
            return RequestMethod.textCompletion
        case .completionItemResolve:
            return RequestMethod.handleCompletionItemResolve
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
            "completionProvider": completionMap,
            "textDocumentSync": 1,
        ]

        let result: [String: Any] = [
            "capabilities": capabilityMap
        ]

        return result
    }

    static func handleCompletionItemResolve(msg: RequestMessageProtocol) throws -> MethodResultProtocol? {
        guard let _ = msg.params as? [String: Any] else {
            throw ResponseError.internalError
        }

        let demoItem: [String: Any] = [
            "label2": "label2",
            "kind2": 3,
            "detail2": "detail2",
            "documentation2": "documentation2",
            "sortText2": "sortText2",
            ]


        return demoItem
    }

    static func handleTextCompletion(msg: RequestMessageProtocol) throws -> MethodResultProtocol? {
        guard let params = msg.params as? [String: Any] else {
            throw ResponseError.internalError
        }

        guard let fileURI: String = params.value(keyPath: "textDocument.uri")
            , let line: Int = params.value(keyPath: "position.line")
            , let character: Int = params.value(keyPath: "position.character")
            else {
                throw RpcErrorCode.invalidParams.toResponseError(msgID: msg.id)
        }

        guard let file = URL(string: fileURI) else {
            Logger.debug("can not get file path.")
            throw RpcErrorCode.invalidParams.toResponseError(msgID: msg.id)
        }

        guard let fileHandle = try? FileHandle(forReadingFrom: file) else {
            Logger.debug("can not get file path.")
            throw RpcErrorCode.invalidParams.toResponseError(msgID: msg.id)
        }

        defer {
            fileHandle.closeFile()
        }

        let bufferLength = 100
        var found = false
        var currentOffset: UInt64 = 0
        var lineCount = 0
        var fileData: Data
        repeat {
            fileData = fileHandle.readData(ofLength: bufferLength)
            if fileData.isEmpty {
                break
            }

            let newlineChar = "\n".data(using: .utf8)!

            var searchStartIndex = fileData.startIndex
            while true {
                if lineCount == line {
                    currentOffset += UInt64(character)
//                    Logger.debug("\(currentOffset)")
                    found = true
                    break
                }

                guard let newlineRange = fileData
                    .range(of: newlineChar, options: [], in: searchStartIndex..<fileData.endIndex)
                    else {
                        currentOffset += UInt64(fileData.endIndex-searchStartIndex)
                        break
                }
//                Logger.debug("\(newlineRange.lowerBound)---\(currentOffset)---\(searchStartIndex)")
                currentOffset += UInt64(newlineRange.lowerBound - searchStartIndex + 1)
                searchStartIndex = newlineRange.lowerBound.advanced(by: 1)
                lineCount += 1
            }

        } while !found



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

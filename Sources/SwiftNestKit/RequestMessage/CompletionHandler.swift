//
//  CompletionHandler.swift
//  SwiftNest
//
//  Created by Carl Chen on 2018/4/13.
//

import Foundation
import SourceKittenFramework

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

        guard let text = SourceFileManager.manager.fileContentFrom(uri: fileURI)
            , let fileData = text.data(using: String.Encoding.utf8) else {
                Logger.error("Can not find file from cache.")
                throw RpcErrorCode.internalError.toResponseError(msgID: msg.id)
        }

        let newlineChar = "\n".data(using: .utf8)!

        var currentOffset: Int64 = 0
        var currentLine = 0
        var searchStartIndex = fileData.startIndex
        while true {
            if currentLine == line {
                currentOffset += Int64(character)
                break
            }

            guard let newlineRange = fileData
                .range(of: newlineChar, options: [], in: searchStartIndex..<fileData.endIndex)
                else {
                    break
            }

            currentOffset += Int64(newlineRange.lowerBound - searchStartIndex + 1)
            searchStartIndex = newlineRange.lowerBound.advanced(by: newlineChar.count)
            currentLine += 1
        }

        let request = Request.codeCompletionRequest(file: ""
            , contents: text
            , offset: currentOffset
            , arguments: [])

        Logger.debug("\(text.count)-\(currentOffset)...."+text)


        let items: [CodeCompletionItem]
        do {
            items = CodeCompletionItem.parse(response: try request.send())
            Logger.debug("\(items.count)")
        } catch {
            items = []
        }

        let itemsList = items.compactMap { (item) -> [String: Any]? in
            guard let label = item.sourcetext
                , let detail = item.typeName
                else {
                    return nil
            }

            return [
                "label": label,
                "kind": 3,
                "detail": detail,
                "sortText": label,
            ]
        }

//        let demoItem: [String: Any] = [
//            "label": "label",
//            "kind": 3,
//            "detail": "detail",
//            "documentation": "documentation",
//            "sortText": "sortText",
//            ]

        let result: [String: Any] = [
            "isIncomplete": false,
            "items": itemsList
        ]

        return result
    }
}

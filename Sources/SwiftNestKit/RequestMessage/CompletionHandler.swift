//
//  CompletionHandler.swift
//  SwiftNest
//
//  Created by Carl Chen on 2018/4/13.
//

import Foundation
import SourceKittenFramework

enum CompletionItemKind: Int {
    case text = 1
    case method = 2
    case function = 3
    case constructor = 4
    case field = 5
    case variable = 6
    case classType = 7
    case interface = 8
    case module = 9
    case property = 10
    case unit = 11
    case value = 12
    case enumType = 13
    case keyword = 14
    case snippet = 15
    case color = 16
    case file = 17
    case reference = 18
    case folder = 19
    case enumMember = 20
    case constant = 21
    case structType = 22
    case event = 23
    case operatorType = 24
    case typeParameter = 25
}

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

        guard let file = URL(string: fileURI), file.isFileURL else {
            Logger.error("Can not find source file.")
            throw RpcErrorCode.internalError.toResponseError(msgID: msg.id)
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
            , arguments: [file.path])

//        Logger.debug("\(text.count)-\(currentOffset)...."+text)


        let items: [CodeCompletionItem]
        do {
            items = CodeCompletionItem.parse(response: try request.send())
        } catch {
            items = []
        }

        /**
         * ref: https://github.com/facebook/nuclide/blob/master/pkg/nuclide-swift/lib/sourcekitten/Complete.js#L57
         */
        let sourceTextHandler: (String) -> (label: String, snippet: String) = {
            (text) in
            let left = "<#T##"
            let right = "#>"

            var label = ""
            var snippet = ""

            var searchStart = text.startIndex
            var index = 1
            while true {
                guard let leftRange = text
                    .range(of: left, options: [], range: searchStart..<text.endIndex, locale: nil)
                    else {
                        label += text[searchStart...]
                        snippet += text[searchStart...]
                        break
                }
                label += text[searchStart..<leftRange.lowerBound]
                snippet += text[searchStart..<leftRange.lowerBound]

                searchStart = leftRange.upperBound

                guard let rightRange = text
                    .range(of: right, options: [], range: searchStart..<text.endIndex, locale: nil) else {
                        let previousIndex = text.index(searchStart, offsetBy: -left.count)
                        label += text[previousIndex...]
                        snippet += text[previousIndex...]
                        break
                }

                let placeText = text[searchStart..<rightRange.lowerBound]
                searchStart = rightRange.upperBound

                let paramText: Substring
                let typeSeparator = "##"
                if let typeRange = placeText.range(of: typeSeparator) {
                    paramText = placeText[..<typeRange.lowerBound]
                } else {
                    paramText = placeText
                }
                label += paramText
                snippet += "${\(index):\(paramText)}"

                index += 1
            }

            return (label, snippet)
        }


        let itemsList = items.compactMap { (item) -> [String: Any]? in
            guard let docBrief = item.docBrief, !docBrief.isEmpty else {
                return nil
            }

            if item.context == "source.codecompletion.context.superclass"
                && item.kind == "source.lang.swift.decl.function.method.instance" {
                // filter superclass methods
                return nil
            }

            guard let sourceText = item.sourcetext
                , let returnTypeName = item.typeName
                else {
                    return nil
            }

            let textInfo = sourceTextHandler(sourceText)

            return [
                "label": textInfo.label,
                "kind": CompletionItemKind.function.rawValue,
                "detail": returnTypeName,
                "sortText": textInfo.label,
                "documentation": docBrief,
                "insertText": textInfo.snippet,
                "insertTextFormat": 2, // snippet
            ]
        }

//        Logger.debug("item count: \(itemsList.count)")

        let result: [String: Any] = [
            "isIncomplete": false,
            "items": itemsList
        ]

        return result
    }
}

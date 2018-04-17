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

    init(sourceKitKind: String) {
        switch sourceKitKind {
        case "source.lang.swift.decl.function.free"
        ,"source.lang.swift.ref.function.free":
            self = .function
        case "source.lang.swift.decl.function.method.instance"
        ,"source.lang.swift.ref.function.method.instance"
        ,"source.lang.swift.decl.function.method.static"
        ,"source.lang.swift.ref.function.method.static":
            self = .method
        case "source.lang.swift.decl.function.operator"
            ,"source.lang.swift.ref.function.operator"
            ,"source.lang.swift.decl.function.subscript"
            ,"source.lang.swift.ref.function.subscript":
            self = .keyword
        case "source.lang.swift.decl.function.constructor"
        ,"source.lang.swift.ref.function.constructor"
        ,"source.lang.swift.decl.function.destructor"
        ,"source.lang.swift.ref.function.destructor":
            self = .constructor
        case "source.lang.swift.decl.function.accessor.getter"
        ,"source.lang.swift.ref.function.accessor.getter"
        ,"source.lang.swift.decl.function.accessor.setter"
        ,"source.lang.swift.ref.function.accessor.setter":
            self = .property
        case "source.lang.swift.decl.class"
        ,"source.lang.swift.ref.class"
        ,"source.lang.swift.decl.struct"
        ,"source.lang.swift.ref.struct":
            self = .classType
        case "source.lang.swift.decl.enum"
        , "source.lang.swift.ref.enum":
            self = .enumType
        case "source.lang.swift.decl.enumelement"
        , "source.lang.swift.ref.enumelement":
            self = .value
        case "source.lang.swift.decl.protocol"
        , "source.lang.swift.ref.protocol":
            self = .interface
        case "source.lang.swift.decl.typealias"
        , "source.lang.swift.ref.typealias":
            self = .reference
        case "source.lang.swift.decl.var.instance"
        , "source.lang.swift.ref.var.instance":
            self = .field
        case "source.lang.swift.decl.var.global"
        ,"source.lang.swift.ref.var.global"
        ,"source.lang.swift.decl.var.static"
        ,"source.lang.swift.ref.var.static"
        ,"source.lang.swift.decl.var.local"
        ,"source.lang.swift.ref.var.local":
            self = .variable

        case "source.lang.swift.decl.extension.struct"
        , "source.lang.swift.decl.extension.class":
            self = .classType
        case "source.lang.swift.decl.extension.enum":
            self = .enumType
        default:
            self = .text //FIXME
        }
    }
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

        let request = Request.codeCompletionRequest(file: file.path
            , contents: text
            , offset: currentOffset
            , arguments: SourceFileManager.manager.generateCompletionArgs(filePath: file.path))

//        Logger.debug("\(text.count)-\(currentOffset)...."+text)


        let items: [CodeCompletionItem]
        do {
            items = CodeCompletionItem.parse(response: try request.send())
        } catch {
            items = []
        }

        Logger.debug("offset[\(currentOffset)].item count: \(items.count).")

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



        var distinctMap: [String: CodeCompletionItem] = [:]
        for item in items {
            guard let sourceText = item.sourcetext, !sourceText.isEmpty else {
                continue
            }

            guard let sameItem = distinctMap[sourceText] else {
                distinctMap[sourceText] = item
                continue
            }

            if item.context == "source.codecompletion.context.thisclass"
                && sameItem.context == "source.codecompletion.context.superclass" {
                // replace sameItem
                distinctMap[sourceText] = item
            }
        }

        var completionItems: [[String: Any]] = []
        for (_, value) in distinctMap {
            guard let sourceText = value.sourcetext
                , let returnTypeName = value.typeName
                else {
                    return nil
            }

            let textInfo = sourceTextHandler(sourceText)
            let kind = CompletionItemKind(sourceKitKind: value.kind)

            var item: [String: Any] = [
                "label": textInfo.label,
                "kind": kind.rawValue,
                "detail": returnTypeName,
                "sortText": textInfo.label,
                "insertText": textInfo.snippet,
                "insertTextFormat": 2, // snippet
            ]

            if value.kind == "source.lang.swift.decl.var.local"
                && returnTypeName != "<<error type>>" {
                item["detail"] = nil
            }

            var document: String = ""
            if let docBrief = value.docBrief, !docBrief.isEmpty {
                document += docBrief
            }

            // if !document.isEmpty {
            //     document += "\n\n"
            // }
            // if let moduleName = value.moduleName, !moduleName.isEmpty {
            //     document += "**Module:** \(moduleName)"
            // }

//            if !document.isEmpty {
//                document += "\n\n"
//            }
//
//            if kind == .function || kind == .method {
//                if let name = value.name, !name.isEmpty {
//                    document += "**Signature:**       \(returnTypeName) \(name)"
//                }
//            }



            if !document.isEmpty {
                item["documentation"] = [
                    "kind": "markdown",
                    "value": document,
                ]
            }

            completionItems.append(item)
        }

//        Logger.debug("item count: \(itemsList.count)")

        let result: [String: Any] = [
            "isIncomplete": false,
            "items": completionItems
        ]

        return result
    }
}

//
//  SwiftNestKit.swift
//  SwiftNest
//
//  Created by Carl Chen on 2018/4/11.
//

import Foundation



public protocol JsonObjectType {}
extension Dictionary: JsonObjectType where Key==String, Value== Any {}

public protocol MethodResultProtocol {
    func toJsonObject() -> JsonObjectType
}

extension Dictionary: MethodResultProtocol where Key==String, Value== Any {
    public func toJsonObject() -> JsonObjectType {
        return self
    }
}

public typealias MethodHandler = (RequestMessageProtocol) throws -> MethodResultProtocol?


public extension SwiftNestKit {
    func register(method: RequestMethod, handler: @escaping MethodHandler) {
        _methodHanlderMap[method] = handler
    }

    func getHandler(method: RequestMethod) -> MethodHandler? {
        return _methodHanlderMap[method]
    }

    func start() {
        Logger.info("Running...")
        kStdin.waitForDataInBackgroundAndNotify()
        RunLoop.main.run()
    }
}

public class SwiftNestKit {
    public static let instance = SwiftNestKit()

    private init () {
        let registerMethods:[RequestMethod] = [
            RequestMethod.shutdown,
            RequestMethod.initialize,
//            RequestMethod.textDocHover,
            RequestMethod.textDocCompletion,
            RequestMethod.completionItemResolve,
        ]

        for method in registerMethods {
            register(method: method, handler: method.getHandler())
        }


        NotificationCenter.default.addObserver(self, selector: #selector(p_receivedInputData(notification:)), name: .NSFileHandleDataAvailable, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    private var _methodHanlderMap: [RequestMethod: MethodHandler] = [:]

    private let kStdin = FileHandle.standardInput
    private let kStdout = FileHandle.standardOutput

    private static let kMaxStdinEmptyCount = 50
    private static var stdinEmptyCount = 0


    private var _unhandledData: Data?
    private var _unhandleContentLength = 0
}

private extension SwiftNestKit {
    @objc func p_receivedInputData(notification: Notification) {
        defer {
            kStdin.waitForDataInBackgroundAndNotify()
        }

        let stdinData = kStdin.availableData
        guard !stdinData.isEmpty else {
            if SwiftNestKit.stdinEmptyCount >= SwiftNestKit.kMaxStdinEmptyCount {
                exit(1)
            }
            Logger.debug("standard input is empty. Ignore")
            SwiftNestKit.stdinEmptyCount += 1
            return
        }
        SwiftNestKit.stdinEmptyCount = 0
        Logger.debug(String(data: stdinData, encoding: String.Encoding.utf8) ?? "")

        do {

            try p_handleNewStdin(stdinData)

        } catch let error as ResponseError {
            let respData = Response.failure(error).toData()
            Logger.debug("something wrong,response ->\n"+String(data: respData, encoding: String.Encoding.utf8)!)
            kStdout.write(respData)
        } catch {
            Logger.error("Catch unknown error.")
            let respData = Response.failure(RpcErrorCode.unknownErrorCode.toResponseError()).toData()
            Logger.error("response ->\n"+String(data: respData, encoding: String.Encoding.utf8)!)
            kStdout.write(respData)
        }

    }

}

// MARK: - Extension: Handle LSP
fileprivate extension SwiftNestKit {
    func p_handleNewStdin(_ input: Data) throws {
        let headerSeparator = "\r\n".data(using: .utf8)!

        var handleData = input
        if let unhandledData = _unhandledData {
            if !unhandledData.isEmpty {
                Logger.debug("Found unhandled data:" + String(data: unhandledData, encoding: .utf8)!)
                handleData = unhandledData + input
            }
            _unhandledData = nil
        }

        if _unhandleContentLength > 0 {
            if _unhandleContentLength > handleData.count {
                return
            } else if _unhandleContentLength == handleData.count {
                p_handleLanguageServerPotocol(data: handleData)
                _unhandleContentLength = 0
                return
            } else {
                let body = handleData[..<self._unhandleContentLength]
                self.p_handleLanguageServerPotocol(data: body)
                self._unhandleContentLength = 0

                handleData = handleData[self._unhandleContentLength...]
            }
        }


        var leftDataRange: Range<Data.Index>?
        var searchStart = handleData.startIndex
        while true {
            guard let separatorRange = handleData
                .range(of: headerSeparator, options: [], in: searchStart..<handleData.endIndex)
                else {
                    if searchStart != handleData.endIndex {
                        leftDataRange = searchStart..<handleData.endIndex
                    }
                    break
            }
            let headerData = handleData[searchStart..<separatorRange.lowerBound]
            searchStart = separatorRange.lowerBound.advanced(by: headerSeparator.count)

            if headerData.count == 0 {
                // found header end, read body from content-length
//                Logger.debug("Found end of header")
                guard _unhandleContentLength > 0 else {
                    Logger.error("can not find valid content length.")
                    throw RpcErrorCode.parseError.toResponseError()
                }

                let leftDataLength = handleData.endIndex - searchStart


                if leftDataLength < _unhandleContentLength {
                    if leftDataLength > 0 {
                        _unhandledData = handleData[searchStart...]
                    }
                    return
                }

                let first = searchStart
                searchStart = searchStart.advanced(by: _unhandleContentLength)

                let body = handleData[first..<searchStart]
                self.p_handleLanguageServerPotocol(data: body)
                self._unhandleContentLength = 0

                continue
            }

            let headerFieldSeparator = ": ".data(using: .utf8)!

            guard let range = headerData.range(of: headerFieldSeparator) else {
                Logger.error("header can not be separated.")
                throw RpcErrorCode.parseError.toResponseError()
            }

            guard let fieldName =
                String(data: headerData[..<range.lowerBound], encoding: String.Encoding.utf8)
                , let value = String(data: headerData[range.upperBound...], encoding: .utf8)
                else {
                    Logger.error("header is not string.")
                    throw RpcErrorCode.parseError.toResponseError()
            }
//            Logger.debug("Found header: \(fieldName), value: \(value)")

            if fieldName == "Content-Length" {
                guard let contentLength = Int(value) else {
                    Logger.error("Content-Length value can not convert to Int.")
                    throw RpcErrorCode.parseError.toResponseError()
                }
                _unhandleContentLength = contentLength
            }

        }

        if let leftRange = leftDataRange {
            Logger.debug("left data range [\(leftRange.lowerBound), \(leftRange.upperBound)]")
            _unhandledData = handleData[leftRange]
        }
    }

    func p_handleLanguageServerPotocol(data: Data) {
//        Logger.debug("rpc bdoy: \(data.count)" + (String(data: data, encoding: .utf8) ?? ""))
        do {
            guard let bodyDic = data.toDictionary() else {
                Logger.error("request content is not json dictionary:" + String(data:data, encoding: .utf8)!)
                throw RpcErrorCode.parseError.toResponseError()
            }

            guard let rpcVersionStr: String = bodyDic.value(key: "jsonrpc")
                , let methodStr: String = bodyDic.value(key: "method") else {
                    throw RpcErrorCode.parseError.toResponseError()
            }

            guard let jsonRpcVersion = JsonRpcVerison(rawValue: rpcVersionStr),
                jsonRpcVersion == JsonRpcVerison.v2_0 else {
                    throw RpcErrorCode.invalidRequest.toResponseError()
            }

            if let msgID: Int = bodyDic.value(key: "id") {
                // request message
                guard let method = RequestMethod(rawValue: methodStr) else {
                    Logger.debug("Not implement meesage \(methodStr) right now.")
                    throw RpcErrorCode.requestCancelled.toResponseError(msgID: msgID)
                }

                guard let params = bodyDic["params"]
                    , let request = RequestMessage(id: msgID, method: method, params: params) else {
                        throw RpcErrorCode.parseError.toResponseError(msgID: msgID)
                }

                let respData = request.response().toData()
                Logger.debug("resp ->\n"+String(data: respData, encoding: String.Encoding.utf8)!)
                kStdout.write(respData)
            } else {
                // it's notification message, do not response
                if let notiMethod = RpcNotification.Method(rawValue: methodStr) {
                    RpcNotification.handleNotification(method: notiMethod, params: bodyDic["params"])
                } else {
                    Logger.debug("SwiftNest don't have a  notification type \(methodStr) right now. maybe add it later.")
                }
            }

        } catch let error as ResponseError {
            let respData = Response.failure(error).toData()
            Logger.debug("something wrong,response ->\n"+String(data: respData, encoding: String.Encoding.utf8)!)
            kStdout.write(respData)
        } catch {
            Logger.error("Catch unknown error.")
            let respData = Response.failure(RpcErrorCode.unknownErrorCode.toResponseError()).toData()
            Logger.error("response ->\n"+String(data: respData, encoding: String.Encoding.utf8)!)
            kStdout.write(respData)
        }
    }
}

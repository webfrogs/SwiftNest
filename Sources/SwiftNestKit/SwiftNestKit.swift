//
//  SwiftNestKit.swift
//  SwiftNest
//
//  Created by Carl Chen on 2018/4/11.
//

import Foundation



public protocol JsonObjectType {}
extension Dictionary: JsonObjectType where Key==String, Value== Any {}

///
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
        MethodHanlderMap[method] = handler
    }

    func getHandler(method: RequestMethod) -> MethodHandler? {
        return MethodHanlderMap[method]
    }

    func start() {
        kStdin.waitForDataInBackgroundAndNotify()
        RunLoop.main.run()
    }
}

public class SwiftNestKit {
    public static let instance = SwiftNestKit()

    private init () {
        register(method: .shutdown) { (msg) -> MethodResultProtocol? in
            // Do nothing when receive a shutdown message.
            return nil
        }
        NotificationCenter.default.addObserver(self, selector: #selector(p_receivedInputData(notification:)), name: .NSFileHandleDataAvailable, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    private var MethodHanlderMap: [RequestMethod: MethodHandler] = [:]

    private let kStdin = FileHandle.standardInput
    private let kStdout = FileHandle.standardOutput

    private static let kMaxStdinEmptyCount = 50
    private static var stdinEmptyCount = 0
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
            Logger.info("standard input is empty. Ignore")
            SwiftNestKit.stdinEmptyCount += 1
            return
        }
        SwiftNestKit.stdinEmptyCount = 0

        do {
            let rpc = try p_handleRpcProtocol(data: stdinData)
            if rpc.headers.count == 0 || rpc.body.count == 0 {
                throw RpcErrorCode.parseError.toResponseError()
            }
            Logger.info(String(data: stdinData, encoding: String.Encoding.utf8) ?? "")

            let bodyLength = rpc.headers
                .first { (header) -> Bool in
                    return header.name == "Content-Length"
                }
                .flatMap { (header) -> Int? in
                    return Int(header.value)
            }

            guard bodyLength == rpc.body.count else {
                Logger.error("request content length not match")
                throw RpcErrorCode.parseError.toResponseError()
            }

            guard let bodyDic = rpc.body.toDictionary() else {
                Logger.error("request content is not json dictionary")
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
                    Logger.info("Not implement \(methodStr) right now.")
                    throw RpcErrorCode.requestCancelled.toResponseError()
                }

                guard let params = bodyDic["params"]
                    , let request = RequestMessage(id: msgID, method: method, params: params) else {
                    throw RpcErrorCode.parseError.toResponseError()
                }

                let respData = request.response().toData()
                Logger.info("resp ->\n"+String(data: respData, encoding: String.Encoding.utf8)!)
                kStdout.write(respData)
            } else {
                // it's notification message, do not response
                if let notiMethod = RpcNotification.Method(rawValue: methodStr) {
                    RpcNotification.handleNotification(method: notiMethod, params: bodyDic["params"])
                } else {
                    Logger.info("SwiftNest don't have a  notification type \(methodStr) right now. maybe add it later.")
                }
            }

        } catch let error as ResponseError {
            let respData = Response.failure(msgID: nil, data: error).toData()
            Logger.info("something wrong,response ->\n"+String(data: respData, encoding: String.Encoding.utf8)!)
            kStdout.write(respData)
        } catch {
            Logger.error("Catch unknown error.")
            let respData = Response.failure(msgID: nil, data: RpcErrorCode.unknownErrorCode.toResponseError()).toData()
            Logger.error("response ->\n"+String(data: respData, encoding: String.Encoding.utf8)!)
            kStdout.write(respData)
        }

    }

    func p_handleRpcProtocol(data: Data) throws -> (headers: [RequestHeader], body: Data) {
        var headersData: [Data] = []
        var body = Data()

        let separatorArray = "\r\n".unicodeScalars.filter({$0.isASCII}).map({UInt8($0.value)})
        var index = 0
        var first = index
        while index < data.count {
            defer {
                index = index + 1
            }

            // current match first separator character
            guard data[index] == separatorArray[0] && (index + 1) < data.count else {
                continue
            }

            // next byte match second separator character
            guard data[index+1] == separatorArray[1] else {
                continue
            }

            // Got a header
            let header = data[first..<index]
            headersData.append(header)

            // Test the end of header
            if (index + 3) < data.count
                && data[index+2] == separatorArray[0]
                && data[index+3] == separatorArray[1] {
                // header end. Got body then end the while loop
                if (index+4) < data.count {
                    body = data[(index+4)...]
                }
                break
            }

            // skip next character test
            index = index + 1
        }

        let headers = try headersData
            .map { (data) -> (String, String) in
                guard let str = String(data: data, encoding: String.Encoding.utf8) else {
                    throw RpcErrorCode.parseError.toResponseError()
                }
                let split = str.components(separatedBy: ": ")
                guard split.count == 2 else {
                    throw RpcErrorCode.parseError.toResponseError()
                }
                return (split[0], split[1])
            }
            .filter { (header) -> Bool in
                return !header.0.isEmpty && !header.1.isEmpty
        }

        return (headers, body)
    }


}

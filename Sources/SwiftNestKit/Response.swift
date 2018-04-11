//
//  Response.swift
//  SwiftNest
//
//  Created by Carl Chen on 2018/4/11.
//

import Foundation

enum RpcErrorCode: Int {
    // Defined by JSON RPC
    case parseError = -32700;
    case invalidRequest = -32600;
    case methodNotFound = -32601;
    case invalidParams = -32602;
    case internalError = -32603;
    case serverErrorStart = -32099;
    case serverErrorEnd = -32000;
    case serverNotInitialized = -32002;
    case unknownErrorCode = -32001;

    // Defined by the protocol.
    case requestCancelled = -32800;
}

enum Response {
    case success(ResponseMessageProtocol)
    case failure(msgID: Int?, data: ResponseError)
}

struct ResponseError: Error {
    let code: RpcErrorCode
    let message: String

    static var unknown: ResponseError {
        return ResponseError(code: .unknownErrorCode, message: "unknown")
    }

    func toJsonDic() -> [String: Any]  {
        return [
            "code": code.rawValue,
            "message": message,
        ]
    }
}

public protocol ResponseMessageProtocol: MessageProtocol {
    var id: Int? { get }
    var result: Any? { get }
}

struct ResponseMessage: ResponseMessageProtocol {
    let jsonrpc: JsonRpcVerison
    let id: Int?
    let result: Any?
}


extension Request {
    func response() -> Response {
        guard let handler = SwiftNestKit.instance.getHandler(method: message.method) else {
            return .failure(msgID: message.id, data: ResponseError.unknown)
        }

        do {
            let data = try handler(message)
            let respMsg = ResponseMessage(jsonrpc: .v2_0, id: message.id, result: data)
            return .success(respMsg)
        } catch let error as ResponseError {
            return .failure(msgID: message.id, data: error)
        } catch {
            return .failure(msgID: message.id, data: ResponseError.unknown)
        }
    }
}

extension Response {
    func toData() -> Data {
        var contentMap: [String: Any] = [:]
        contentMap["jsonrpc"] = JsonRpcVerison.v2_0.rawValue

        switch self {
        case let .success(respMsg):
            contentMap["id"] = respMsg.id
            contentMap["result"] = respMsg.result
        case let .failure(msgID, error):
            contentMap["id"] = msgID
            contentMap["error"] = error.toJsonDic()
        }


        let respContentData: Data
        do {
            respContentData = try JSONSerialization.data(withJSONObject: contentMap, options: [])
        } catch {
            respContentData = """
{
    "id": null
}
""".data(using: String.Encoding.utf8)!
        }

        var result: Data = "Content-Length: \(respContentData.count)\r\n\r\n"
            .data(using: String.Encoding.utf8)!
        result = result + respContentData
        return result
    }
}


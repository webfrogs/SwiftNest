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

    func toResponseError(msgID: Int? = nil, msg: String = "") -> ResponseError {
        return ResponseError(code: self, message: msg, msgID: msgID)
    }
}

enum Response {
    case success(ResponseMessageProtocol)
    case failure(ResponseError)
}

public struct ResponseError: Error {
    let code: RpcErrorCode
    let message: String
    let msgID: Int?

    func toJsonDic() -> [String: Any]  {
        return [
            "code": code.rawValue,
            "message": message,
        ]
    }

    public static var internalError: ResponseError {
        return RpcErrorCode.internalError.toResponseError()
    }
}

public protocol ResponseMessageProtocol: MessageProtocol {
    var id: Int? { get }
    var result: JsonObjectType? { get }
}

struct ResponseMessage: ResponseMessageProtocol {
    let jsonrpc: JsonRpcVerison
    let id: Int?
    let result: JsonObjectType?
}

extension RequestMessageProtocol {
    func response() -> Response {
        guard let handler = SwiftNestKit.instance.getHandler(method: method) else {
            let err = RpcErrorCode.requestCancelled
                .toResponseError(msgID: id, msg: "No handler is found.")
            return .failure(err)
        }

        do {
            let jsonObject = try handler(self)?.toJsonObject()
            let respMsg = ResponseMessage(jsonrpc: .v2_0, id: id, result: jsonObject)
            return .success(respMsg)
        } catch let error as ResponseError {
            return .failure(error)
        } catch {
            let err = RpcErrorCode.unknownErrorCode.toResponseError(msgID: id, msg: "unknown")
            return .failure(err)
        }
    }
}


extension Response {
    func toData() -> Data {
        var contentMap: [String: Any] = [:]
        contentMap["jsonrpc"] = JsonRpcVerison.v2_0.rawValue

        let messageID: Int?
        switch self {
        case let .success(respMsg):
            messageID = respMsg.id
            contentMap["id"] = respMsg.id
            contentMap["result"] = respMsg.result ?? NSNull()
        case let .failure(error):
            messageID = error.msgID
            contentMap["id"] = messageID ?? NSNull()
            contentMap["error"] = error.toJsonDic()
        }

        let respContentData: Data
        do {
            if JSONSerialization.isValidJSONObject(contentMap) {
                respContentData = try JSONSerialization.data(withJSONObject: contentMap, options: [])
            } else {
                Logger.error("response map can't convert to json data.")
                let msgIDJsonStr = messageID == nil ? "null": "\(messageID!)"
                respContentData = "{\"error\"=\(RpcErrorCode.internalError),\"id\"=\(msgIDJsonStr)\"}"
                    .data(using: String.Encoding.utf8)!
            }
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


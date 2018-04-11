import Foundation
import Transformers

public enum JsonRpcVerison: String {
    case v2_0 = "2.0"
}




public protocol MessageProtocol {
    var jsonrpc: JsonRpcVerison { get }
}

public protocol RequestMessageProtocol: MessageProtocol {
    var id: Int { get }
    var method: Method { get }
    var params: Any { get }
}



public struct RequestMessage: RequestMessageProtocol {
    public let jsonrpc: JsonRpcVerison
    public let id: Int
    public let method: Method
    public var params: Any
}

public struct Request {
    public let message: RequestMessage

    public init?(data: Data) {
        let info = Request.handle(data: data)

        if info.headers.count == 0 || info.body.count == 0 {
            Logger.error("Can't handle request data")
            return nil
        }

        Logger.info(String(data: data, encoding: String.Encoding.utf8) ?? "")

        let bodyLength = info.headers
            .first { (header) -> Bool in
                return header.name == "Content-Length"
            }
            .flatMap { (header) -> Int? in
                return Int(header.value)
            }

        guard bodyLength == info.body.count else {
            Logger.error("request content length not match")
            return nil
        }

        guard let bodyDic = info.body.toDictionary() else {
            Logger.error("request content is not json dictionary")
            return nil
        }

        guard let jsonRpcVersion = bodyDic.value(key: "jsonrpc").flatMap(JsonRpcVerison.init),
            let id: Int = bodyDic.value(key: "id"),
            let methodStr: String = bodyDic.value(key: "method"),
            let params: Any = bodyDic.value(key: "params")
            else {
                return nil
        }

        if methodStr == "shutdown" {
            Logger.info("Receive shutdown command, exit.")
            exit(0)
        }
        guard let method = Method(rawValue: methodStr) else {
            return nil
        }


        self.message = RequestMessage(jsonrpc: jsonRpcVersion, id: id, method: method, params: params)
    }
}

typealias RequestHeader = (name: String, value: String)

extension Request {
    fileprivate static func handle(data: Data) -> (headers: [RequestHeader], body: Data) {
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

        let headers = headersData
            .map { (data) -> (String, String) in
                guard let str = String(data: data, encoding: String.Encoding.utf8) else {
                    Logger.error("Something wrong in request data")
                    return ("", "")
                }
                let split = str.components(separatedBy: ": ")
                guard split.count == 2 else {
                    Logger.error("Something wrong in request data")
                    return ("", "")
                }
                return (split[0], split[1])
            }
            .filter { (header) -> Bool in
                return !header.0.isEmpty && !header.1.isEmpty
            }

        return (headers, body)
    }
}

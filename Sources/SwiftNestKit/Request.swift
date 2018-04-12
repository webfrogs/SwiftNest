import Foundation
import Transformers

public enum RequestMethod: String {
    case initialize
    case shutdown
}


public enum JsonRpcVerison: String {
    case v2_0 = "2.0"
}

typealias RequestHeader = (name: String, value: String)

public protocol MessageProtocol {
    var jsonrpc: JsonRpcVerison { get }
}

public protocol MessageMethodProtocol {
    var method: RequestMethod { get }
}

public protocol ParamsType {}
extension Dictionary: ParamsType where Key==String, Value==Any {}

public protocol RequestMessageParamsProtocol {
    var id: Int { get }
    var params: ParamsType? { get }
}


public protocol RequestMessageProtocol: MessageProtocol, MessageMethodProtocol, RequestMessageParamsProtocol {
}

public struct RequestMessage: RequestMessageProtocol {
    public let jsonrpc = JsonRpcVerison.v2_0
    public let id: Int
    public let method: RequestMethod
    public let params: ParamsType?

    init?(id: Int, method: RequestMethod, params: Any?) {
        switch method {
        case .initialize:
            if params == nil {
                self.params = nil
                break
            }
            guard let dic = params as? [String: Any] else {
                return nil
            }
            self.params = dic
        case .shutdown:
            return nil
        }

        self.id = id
        self.method = method
    }
}



import Foundation
import SwiftNestKit


let nest = SwiftNestKit.instance

nest.register(method: .initialize) { (msg) -> MethodResultProtocol? in
    guard let _ = msg.params as? [String: Any] else {
        throw ResponseError.internalError
    }

    let capabilityMap: [String: Any] = [
        "hoverProvider": true,
    ]

    let result: [String: Any] = [
        "capabilities": capabilityMap
    ]

    return result
}


nest.start()


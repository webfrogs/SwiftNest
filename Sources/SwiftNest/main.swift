import Foundation
import SwiftNestKit


let nest = SwiftNestKit.instance

nest.register(method: .initialize) { (msg) -> Data? in
    return nil
}


nest.start()


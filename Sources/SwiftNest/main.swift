import Foundation
import SwiftNestKit

let currentVersion = "0.0.1"

let arguments = CommandLine.arguments
if arguments.count == 2 && arguments[1] == "--version" {
    print(currentVersion)
    exit(0)
}

let nest = SwiftNestKit.instance
nest.start()

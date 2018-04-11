import Foundation

let stdin = FileHandle.standardInput
let stdout = FileHandle.standardOutput
stdin.waitForDataInBackgroundAndNotify()

NotificationCenter.default
    .addObserver(forName: .NSFileHandleDataAvailable, object: nil, queue: OperationQueue.main) {
        (notification: Notification) in
        defer {
            stdin.waitForDataInBackgroundAndNotify()
        }

        let stdinData = stdin.availableData
        guard !stdinData.isEmpty else {
            return
        }

        stdout.write(stdinData)
    }

RunLoop.main.run()

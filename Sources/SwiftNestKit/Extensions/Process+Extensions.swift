import Foundation

extension Process {
    static func syncRun(shell: String
        , currentDir: String? = nil
        , envrionment: [String: String] = [:]) -> Bool {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", shell]
        if let path = currentDir, !path.isEmpty {
            task.currentDirectoryPath = path
        }
        if envrionment.count > 0 {
            task.environment = envrionment
        }

        task.launch()
        task.waitUntilExit()

        return task.terminationStatus == EX_OK
    }

    static func syncRunWithOutput(shell: String
        , currentDir: String? = nil
        , envrionment: [String: String] = [:]) -> String? {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", shell]
        if let path = currentDir, !path.isEmpty {
            task.currentDirectoryPath = path
        }
        if envrionment.count > 0 {
            task.environment = envrionment
        }

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard task.terminationStatus == EX_OK
            , let output = String(data: data, encoding: String.Encoding.utf8) else {
                return nil
        }

        return output
    }
}

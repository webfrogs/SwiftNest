//
//  SwiftNestKit.swift
//  SwiftNest
//
//  Created by Carl Chen on 2018/4/11.
//

import Foundation

public enum Method: String {
    case initialize
}

public typealias MethodHandler = (RequestMessageProtocol) throws -> Data? // TODO: not data but something can be json

public extension SwiftNestKit {
    func register(method: Method, handler: @escaping MethodHandler) {
        MethodHanlderMap[method] = handler
    }

    func getHandler(method: Method) -> MethodHandler? {
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
        NotificationCenter.default.addObserver(self, selector: #selector(p_receivedInputData(notification:)), name: .NSFileHandleDataAvailable, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    private var MethodHanlderMap: [Method: MethodHandler] = [:]

    private let kStdin = FileHandle.standardInput
    private let kStdout = FileHandle.standardOutput
}

private extension SwiftNestKit {
    @objc func p_receivedInputData(notification: Notification) {
        defer {
            kStdin.waitForDataInBackgroundAndNotify()
        }

        let stdinData = kStdin.availableData
        guard !stdinData.isEmpty else {
            return
        }

        guard let request = Request(data: stdinData) else {
            return
        }

        let respData = request.response().toData()
        Logger.info("resp ->\n"+String(data: respData, encoding: String.Encoding.utf8)!)
        
        kStdout.write(respData)
    }
}

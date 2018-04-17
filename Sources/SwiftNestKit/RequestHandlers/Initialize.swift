import Foundation

extension RequestMethod {
    static func handleInitialize(msg: RequestMessageProtocol) throws -> MethodResultProtocol? {
        guard let paramsDic = msg.params as? [String: Any] else {
            throw ResponseError.internalError
        }

        guard let rootPath: String = paramsDic.value(keyPath: "rootPath")
            , !rootPath.isEmpty else {
                throw RpcErrorCode.invalidParams.toResponseError(msgID: msg.id)
        }
        SourceFileManager.manager.workspaceRootPath = rootPath
        Logger.info("Set workspace root path: \(rootPath)")
        

//        let completionTrigger = Array("abcdefghigklmnopqrstuvwxyz.").map(String.init)
        let completionTrigger = ["."]

        let completionMap: [String: Any] = [
            "resolveProvider": false,
            "triggerCharacters": completionTrigger,
            ]

        let capabilityMap: [String: Any] = [
//        "hoverProvider": true,
            "completionProvider": completionMap,
            "textDocumentSync": 1,
        ]

        let result: [String: Any] = [
            "capabilities": capabilityMap
        ]

        return result
    }

}
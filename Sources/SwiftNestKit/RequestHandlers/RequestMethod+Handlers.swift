//
//  HandleRequestMessage.swift
//  SwiftNest
//
//  Created by Carl Chen on 2018/4/12.
//

import Foundation


extension RequestMethod {
    func getHandler() -> MethodHandler {
        switch self {
        case .initialize:
            return RequestMethod.handleInitialize
        case .textDocCompletion:
            return RequestMethod.textCompletion
//        case .completionItemResolve:
//            return RequestMethod.handleCompletionItemResolve
        default:
            // done nothing
            return { (msg: RequestMessageProtocol) -> MethodResultProtocol? in return nil }
        }
    }
}


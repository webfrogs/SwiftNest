//
//  SourceFileManager.swift
//  SwiftNest
//
//  Created by Carl Chen on 2018/4/13.
//

import Foundation

extension SourceFileManager {
    func fileContentFrom(uri: String) -> String? {
        return _cachedFile[uri]
    }

    func fileDidOpen(uri: String, text: String) {
        _cachedFile[uri] = text
        Logger.logCurrentMethodIfCalled()
    }

    func fileDidChange(uri: String, text: String) {
        _cachedFile[uri] = text
        Logger.logCurrentMethodIfCalled()
    }

    func fileDidClose(uri: String) {
        _cachedFile[uri] = nil
        Logger.logCurrentMethodIfCalled()
    }
}

class SourceFileManager {
    static let manager = SourceFileManager()
    private init() {}

    private var _cachedFile: [String: String] = [:]
}



//
//  SourceFileManager.swift
//  SwiftNest
//
//  Created by Carl Chen on 2018/4/13.
//

import Foundation

extension SourceFileManager {
    func generateCompletionArgs(filePath: String) -> [String] {
        var result = p_getBaseCompilerArgs()
        if result.isEmpty {
            result.append(filePath)
        }
        return result
    }

    func fileContentFrom(uri: String) -> String? {
        return _cachedFile[uri]
    }

    func fileDidOpen(uri: String, text: String) {
        _cachedFile[uri] = text
    }

    func fileDidChange(uri: String, text: String) {
        _cachedFile[uri] = text
    }

    func fileDidClose(uri: String) {
        _cachedFile[uri] = nil
    }
}

class SourceFileManager {
    var workspaceRootPath: String?

    static let manager = SourceFileManager()
    private init() {}

    private var _cachedFile: [String: String] = [:]
}

private extension SourceFileManager {
    func p_getBaseCompilerArgs() -> [String] {
//        guard let
        guard let workspaceURL = workspaceRootPath.map({URL(fileURLWithPath: $0)})
            , workspaceURL.isSPMProject else {
            return []
        }


        let sourceFolder = workspaceURL.appendingPathComponent("Sources")
        var result = p_getAllSwiftSourceFilePaths(previous: [], url: sourceFolder)


        result.append(contentsOf: ["-I", "\(workspaceURL.path)/.build/debug"])

        #if os(macOS)
        // SPM only support macOS project for now.
        if let sdkPath = Process.syncRunWithOutput(shell: "xcrun --sdk macosx --show-sdk-path")
        , !sdkPath.isEmpty {
            result.append(contentsOf: [
                "-target", "x86_64-apple-macosx10.10",
                "-sdk", sdkPath,
                ])
        }
        #endif

        return result
    }

    func p_getAllSwiftSourceFilePaths(previous: [String] , url: URL) -> [String] {
        guard let fileEnumerator = FileManager.default.enumerator(atPath: url.path) else {
            return previous
        }

        var result = previous
        while let element = fileEnumerator.nextObject() as? String {
            guard let attributeType = fileEnumerator.fileAttributes?[FileAttributeKey.type] as? FileAttributeType
                else {
                    continue
            }

            let elementURL = url.appendingPathComponent(element)
            switch attributeType {
            case FileAttributeType.typeRegular:
                if elementURL.pathExtension == "swift" {
                    result.append(elementURL.path)
                }
            default:
                continue
            }
        }

        return result
    }

}

private extension URL {

    var isSPMProject: Bool {
        return self.appendingPathComponent("Package.swift").fileExists
    }

    var fileExists: Bool {
        guard self.isFileURL else {
            return false
        }
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: self.path, isDirectory: &isDir)
        return exists && !isDir.boolValue
    }
}



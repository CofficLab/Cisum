import Foundation
import OSLog
import SwiftUI
#if os(macOS)
extension ShellGit {
    /// 将文件添加到暂存区
    /// - Parameters:
    ///   - files: 要添加的文件路径数组，为空则添加所有文件
    ///   - path: 仓库路径
    public static func add(_ files: [String] = [], at path: String? = nil) throws {
        try Shell.runSync(addCommand(files), at: path)
    }
    
    /// 将文件从暂存区移除
    /// - Parameters:
    ///   - files: 要移除的文件路径数组，为空则移除所有文件
    ///   - path: 仓库路径
    public static func reset(_ files: [String] = [], at path: String? = nil) throws {
        try Shell.runSync(resetStagedCommand(files), at: path)
    }

    static func addCommand(_ files: [String] = []) -> String {
        "git add -- \(pathspecArguments(files))"
    }

    static func resetStagedCommand(_ files: [String] = []) -> String {
        "git reset -- \(pathspecArguments(files))"
    }

    static func pathspecArguments(_ files: [String]) -> String {
        files.isEmpty ? "." : files.map(shellQuoted).joined(separator: " ")
    }
}
#endif

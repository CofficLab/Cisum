import Foundation
import OSLog
import SwiftUI

#if os(macOS)
extension ShellGit {
    /// 重置文件或文件夹到指定状态
    /// - Parameters:
    ///   - files: 要重置的文件路径数组，如果为空则重置所有文件
    ///   - mode: 重置模式 (--hard, --soft, --mixed)
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func reset(_ files: [String] = [], mode: String? = nil, at path: String? = nil) throws -> String {
        return try Shell.runSync(resetCommand(files: files, mode: mode), at: path)
    }

    static func resetCommand(files: [String] = [], mode: String? = nil) -> String {
        var command = "git reset"
        if let mode = mode {
            command += " \(shellQuoted(mode))"
        }
        if !files.isEmpty {
            command += " -- " + files.map(shellQuoted).joined(separator: " ")
        }
        return command
    }
    
    /// 硬重置到指定提交
    /// - Parameters:
    ///   - commitHash: 提交哈希值，如果为空则重置到HEAD
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func resetHard(_ commitHash: String? = nil, at path: String? = nil) throws -> String {
        let target = commitHash ?? "HEAD"
        return try Shell.runSync(resetToCommitCommand(mode: "--hard", target: target), at: path)
    }
    
    /// 软重置到指定提交
    /// - Parameters:
    ///   - commitHash: 提交哈希值，如果为空则重置到HEAD
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func resetSoft(_ commitHash: String? = nil, at path: String? = nil) throws -> String {
        let target = commitHash ?? "HEAD"
        return try Shell.runSync(resetToCommitCommand(mode: "--soft", target: target), at: path)
    }
    
    /// 混合重置到指定提交
    /// - Parameters:
    ///   - commitHash: 提交哈希值，如果为空则重置到HEAD
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func resetMixed(_ commitHash: String? = nil, at path: String? = nil) throws -> String {
        let target = commitHash ?? "HEAD"
        return try Shell.runSync(resetToCommitCommand(mode: "--mixed", target: target), at: path)
    }

    static func resetToCommitCommand(mode: String, target: String) -> String {
        "git reset \(mode) \(shellQuoted(target))"
    }
    
    /// 重置指定文件到HEAD状态
    /// - Parameters:
    ///   - file: 文件路径
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func resetFile(_ file: String, at path: String? = nil) throws -> String {
        return try Shell.runSync(resetFileCommand(file), at: path)
    }

    static func resetFileCommand(_ file: String) -> String {
        "git reset HEAD \(shellQuoted(file))"
    }
    
    /// 重置所有暂存区文件
    /// - Parameter path: 仓库路径
    /// - Returns: 执行结果
    public static func resetStaged(at path: String? = nil) throws -> String {
        return try Shell.runSync("git reset HEAD", at: path)
    }
}
#endif

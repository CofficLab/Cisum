import Foundation
import OSLog
import SwiftUI
#if os(macOS)
extension ShellGit {
    /// 合并分支
    /// - Parameters:
    ///   - branchName: 要合并的分支名称
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func merge(_ branchName: String, at path: String? = nil) throws -> String {
        return try Shell.runSync(mergeCommand(branchName), at: path)
    }
    
    /// 快进合并
    /// - Parameters:
    ///   - branchName: 要合并的分支名称
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func mergeFastForward(_ branchName: String, at path: String? = nil) throws -> String {
        return try Shell.runSync(mergeFastForwardCommand(branchName), at: path)
    }
    
    /// 非快进合并（创建合并提交）
    /// - Parameters:
    ///   - branchName: 要合并的分支名称
    ///   - message: 合并提交信息
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func mergeNoFastForward(_ branchName: String, message: String? = nil, at path: String? = nil) throws -> String {
        return try Shell.runSync(mergeNoFastForwardCommand(branchName, message: message), at: path)
    }
    
    /// 压缩合并（将分支的所有提交压缩为一个提交）
    /// - Parameters:
    ///   - branchName: 要合并的分支名称
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func mergeSquash(_ branchName: String, at path: String? = nil) throws -> String {
        return try Shell.runSync(mergeSquashCommand(branchName), at: path)
    }
    
    /// 使用指定策略合并
    /// - Parameters:
    ///   - branchName: 要合并的分支名称
    ///   - strategy: 合并策略（ours, theirs, recursive, resolve, octopus, subtree）
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func mergeWithStrategy(_ branchName: String, strategy: String, at path: String? = nil) throws -> String {
        return try Shell.runSync(mergeWithStrategyCommand(branchName, strategy: strategy), at: path)
    }
    
    /// 中止合并
    /// - Parameter path: 仓库路径
    /// - Returns: 执行结果
    public static func mergeAbort(at path: String? = nil) throws -> String {
        return try Shell.runSync("git merge --abort", at: path)
    }
    
    /// 继续合并（解决冲突后）
    /// - Parameter path: 仓库路径
    /// - Returns: 执行结果
    public static func mergeContinue(at path: String? = nil) throws -> String {
        return try Shell.runSync("git merge --continue", at: path)
    }
    
    /// 检查是否正在进行合并
    /// - Parameter path: 仓库路径
    /// - Returns: 是否正在合并
    public static func isMerging(at path: String? = nil) throws -> Bool {
        do {
            _ = try Shell.runSync("git rev-parse --verify MERGE_HEAD", at: path)
            return true
        } catch {
            return false
        }
    }
    
    /// 获取合并冲突文件列表
    /// - Parameter path: 仓库路径
    /// - Returns: 冲突文件列表
    public static func mergeConflictFiles(at path: String? = nil) throws -> [String] {
        let output = try Shell.runSync("git diff --name-only --diff-filter=U", at: path)
        return output.split(separator: "\n").map { String($0) }.filter { !$0.isEmpty }
    }
    
    /// 获取合并状态信息
    /// - Parameter path: 仓库路径
    /// - Returns: 合并状态信息
    public static func mergeStatus(at path: String? = nil) throws -> String {
        if try isMerging(at: path) {
            let conflictFiles = try mergeConflictFiles(at: path)
            if conflictFiles.isEmpty {
                return mergeStatusMessage(isMerging: true, conflictFiles: [])
            } else {
                return mergeStatusMessage(isMerging: true, conflictFiles: conflictFiles)
            }
        } else {
            return mergeStatusMessage(isMerging: false, conflictFiles: [])
        }
    }

    public static func mergeStatusMessage(isMerging: Bool, conflictFiles: [String]) -> String {
        guard isMerging else { return "Not currently merging" }
        guard !conflictFiles.isEmpty else { return "Merging with no conflict files" }
        return "Merging with conflicts: \(conflictFiles.joined(separator: ", "))"
    }
    
    /// 使用我们的版本解决冲突
    /// - Parameters:
    ///   - files: 文件列表，为空则应用于所有冲突文件
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func mergeResolveOurs(_ files: [String] = [], at path: String? = nil) throws -> String {
        return try Shell.runSync(mergeResolveOursCommand(files), at: path)
    }
    
    /// 使用他们的版本解决冲突
    /// - Parameters:
    ///   - files: 文件列表，为空则应用于所有冲突文件
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func mergeResolveTheirs(_ files: [String] = [], at path: String? = nil) throws -> String {
        return try Shell.runSync(mergeResolveTheirsCommand(files), at: path)
    }

    static func mergeCommand(_ branchName: String) -> String {
        "git merge \(shellQuoted(branchName))"
    }

    static func mergeFastForwardCommand(_ branchName: String) -> String {
        "git merge --ff-only \(shellQuoted(branchName))"
    }

    static func mergeNoFastForwardCommand(_ branchName: String, message: String? = nil) -> String {
        var command = "git merge --no-ff \(shellQuoted(branchName))"
        if let message {
            command += " -m \(shellQuoted(message))"
        }
        return command
    }

    static func mergeSquashCommand(_ branchName: String) -> String {
        "git merge --squash \(shellQuoted(branchName))"
    }

    static func mergeWithStrategyCommand(_ branchName: String, strategy: String) -> String {
        "git merge -s \(shellQuoted(strategy)) \(shellQuoted(branchName))"
    }

    static func mergeResolveOursCommand(_ files: [String] = []) -> String {
        if files.isEmpty {
            return "git checkout --ours ."
        } else {
            let filesStr = files.map(shellQuoted).joined(separator: " ")
            return "git checkout --ours -- \(filesStr)"
        }
    }

    static func mergeResolveTheirsCommand(_ files: [String] = []) -> String {
        if files.isEmpty {
            return "git checkout --theirs ."
        } else {
            let filesStr = files.map(shellQuoted).joined(separator: " ")
            return "git checkout --theirs -- \(filesStr)"
        }
    }
}
#endif

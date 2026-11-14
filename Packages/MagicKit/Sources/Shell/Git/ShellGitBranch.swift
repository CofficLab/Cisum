import Foundation
import OSLog
import SwiftUI
#if os(macOS)
extension ShellGit {
    /// 获取分支列表
    /// - Parameters:
    ///   - includeRemote: 是否包含远程分支
    ///   - path: 仓库路径
    /// - Returns: 分支列表
    public static func branches(includeRemote: Bool = false, at path: String? = nil) throws -> String {
        let option = includeRemote ? "-a" : ""
        return try Shell.runSync("git branch \(option)", at: path)
    }

    /// 获取分支列表并返回字符串数组
    /// - Parameters:
    ///   - includeRemote: 是否包含远程分支
    ///   - path: 仓库路径
    /// - Returns: 分支名称字符串数组
    public static func branchesArray(includeRemote: Bool = false, at path: String? = nil) throws -> [String] {
        let branchesString = try branches(includeRemote: includeRemote, at: path)
        return branchesString.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "* ", with: "") }.filter { !$0.isEmpty }
    }
    
    /// 获取当前分支
    /// - Parameter path: 仓库路径
    /// - Returns: 当前分支名
    public static func currentBranch(at path: String? = nil) throws -> String {
        return try Shell.runSync("git branch --show-current", at: path).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 获取所有本地分支
    /// - Parameter path: 仓库路径
    /// - Returns: 本地分支列表
    public static func localBranches(at path: String? = nil) throws -> [String] {
        let output = try Shell.runSync("git branch", at: path)
        return output.split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: "* ", with: "") }
    }
    
    /// 获取所有远程分支
    /// - Parameter path: 仓库路径
    /// - Returns: 远程分支列表
    public static func remoteBranches(at path: String? = nil) throws -> [String] {
        let output = try Shell.runSync("git branch -r", at: path)
        return output.split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    /// 获取所有分支（本地+远程）
    /// - Parameter path: 仓库路径
    /// - Returns: 所有分支列表
    public static func allBranches(at path: String? = nil) throws -> [String] {
        let output = try Shell.runSync("git branch -a", at: path)
        return output.split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: "* ", with: "") }
    }
    
    /// 创建新分支
    /// - Parameters:
    ///   - name: 分支名称
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func createBranch(_ name: String, at path: String? = nil) throws -> String {
        return try Shell.runSync("git branch \(shellQuoted(name))", at: path)
    }
    
    /// 删除本地分支
    /// - Parameters:
    ///   - name: 分支名称
    ///   - force: 是否强制删除（即使分支还没有被合并）
    ///   - path: 仓库路径，默认为当前目录
    /// - Returns: 删除结果
    /// - Throws: 如果删除失败
    public static func deleteBranch(_ name: String, force: Bool = false, at path: String? = nil) throws -> String {
        let forceFlag = force ? "-D" : "-d"
        return try Shell.runSync("git branch \(forceFlag) \(shellQuoted(name))", at: path)
    }
    
    /// 获取分支的最后一次提交
    /// - Parameters:
    ///   - branchName: 分支名称
    ///   - path: 仓库路径
    /// - Returns: 最后一次提交的简短信息
    public static func lastCommitOfBranch(_ branchName: String, at path: String? = nil) throws -> String {
        return try Shell.runSync("git log \(shellQuoted(branchName)) -1 --oneline", at: path)
    }

    /// 获取分支结构体列表
    /// - Parameters:
    ///   - includeRemote: 是否包含远程分支
    ///   - path: 仓库路径
    /// - Returns: 分支结构体数组
    public static func branchList(includeRemote: Bool = false, at path: String? = nil) throws -> [MagicGitBranch] {
        let branchesString = try branches(includeRemote: includeRemote, at: path)
        let lines = branchesString.split(separator: "\n").map { String($0) }
        let currentBranchName = try? currentBranch(at: path)
        var result: [MagicGitBranch] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let name = trimmed.replacingOccurrences(of: "* ", with: "")
            // 获取上游、最新 commit hash/message 可后续扩展
            result.append(MagicGitBranch(id: name, name: name, isCurrent: currentBranchName == name, upstream: nil, latestCommitHash: "", latestCommitMessage: ""))
        }
        return result
    }

    /// 获取当前分支（结构体版）
    /// - Parameter path: 仓库路径
    /// - Returns: 当前分支 GitBranch 结构体
    public static func currentBranchInfo(at path: String? = nil) throws -> MagicGitBranch? {
        let name = try currentBranch(at: path).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        // 可扩展：获取上游、最新 commit hash/message
        return MagicGitBranch(id: name, name: name, isCurrent: true, upstream: nil, latestCommitHash: "", latestCommitMessage: "")
    }
}
#endif

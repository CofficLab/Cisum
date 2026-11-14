import Foundation
import OSLog
import SwiftUI

#if os(macOS)
extension ShellGit {
    /// 暂存更改
    /// - Parameters:
    ///   - message: 暂存信息
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func stash(_ message: String? = nil, at path: String? = nil) throws -> String {
        let command = if let message {
            "git stash push -m \(shellQuoted(message))"
        } else {
            "git stash"
        }
        return try Shell.runSync(command, at: path)
    }
    
    /// 恢复暂存
    /// - Parameters:
    ///   - index: 暂存索引，默认为最新
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func stashPop(index: Int = 0, at path: String? = nil) throws -> String {
        return try Shell.runSync("git stash pop stash@{\(index)}", at: path)
    }
    
    /// 获取暂存列表
    /// - Parameter path: 仓库路径
    /// - Returns: 暂存列表
    public static func stashList(at path: String? = nil) throws -> String {
        return try Shell.runSync("git stash list", at: path)
    }
    
    /// 获取暂存列表（结构体版）
    /// - Parameter path: 仓库路径
    /// - Returns: [MagicGitStash]
    public static func stashListArray(at path: String? = nil) throws -> [MagicGitStash] {
        let list = try stashList(at: path)
        let lines = list.split(separator: "\n").map { String($0) }
        var result: [MagicGitStash] = []
        for (idx, line) in lines.enumerated() {
            // 例：stash@{0}: On main: 测试暂存
            let desc = line
            let commitHash = (try? Shell.runSync("git rev-parse stash@{\(idx)}^0", at: path)) ?? ""
            result.append(MagicGitStash(id: idx, description: desc, commitHash: commitHash, date: nil))
        }
        return result
    }
}

#endif

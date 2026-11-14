import Foundation
import OSLog
import SwiftUI

#if os(macOS)
extension ShellGit {
    /// 获取标签列表
    /// - Parameter path: 仓库路径
    /// - Returns: 标签列表
    public static func tags(at path: String? = nil) throws -> String {
        return try Shell.runSync("git tag", at: path)
    }
    
    /// 创建标签
    /// - Parameters:
    ///   - name: 标签名称
    ///   - message: 标签信息
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func createTag(_ name: String, message: String? = nil, at path: String? = nil) throws -> String {
        return try Shell.runSync(createTagCommand(name, message: message), at: path)
    }
    
    /// 删除标签
    /// - Parameters:
    ///   - name: 标签名称
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func deleteTag(_ name: String, at path: String? = nil) throws -> String {
        return try Shell.runSync(deleteTagCommand(name), at: path)
    }
    
    /// 获取指定 commit 的所有标签
    /// - Parameters:
    ///   - commit: commit 哈希
    ///   - path: 仓库路径
    /// - Returns: 标签数组
    public static func tags(for commit: String, at path: String? = nil) throws -> [String] {
        let output = try Shell.runSync(tagsForCommitCommand(commit), at: path)
        return output.split(separator: "\n").map { String($0) }.filter { !$0.isEmpty }
    }
    
    /// 获取标签结构体列表
    /// - Parameter path: 仓库路径
    /// - Returns: 标签结构体数组
    public static func tagList(at path: String? = nil) throws -> [MagicGitTag] {
        let tagNames = try tags(at: path).split(separator: "\n").map { String($0) }
        var tags: [MagicGitTag] = []
        for name in tagNames {
            // 获取 commit hash
            let commitHash = (try? Shell.runSync(tagCommitHashCommand(name), at: path)) ?? ""
            // 获取作者、日期、message
            let tagInfo = (try? Shell.runSync(tagInfoCommand(name), at: path)) ?? "::"
            let parts = tagInfo.split(separator: "::").map { String($0) }
            let author = parts.count > 0 ? parts[0] : nil
            let date = parts.count > 1 ? ISO8601DateFormatter().date(from: parts[1]) : nil
            let message = parts.count > 2 ? parts[2] : nil
            tags.append(MagicGitTag(id: name, name: name, commitHash: commitHash, author: author, date: date, message: message))
        }
        return tags
    }
    
    /// 获取指定 commit 的所有标签（结构体版）
    /// - Parameters:
    ///   - commit: commit 哈希
    ///   - path: 仓库路径
    /// - Returns: [MagicGitTag]
    public static func tagList(for commit: String, at path: String? = nil) throws -> [MagicGitTag] {
        let tagNames = try tags(for: commit, at: path)
        var tags: [MagicGitTag] = []
        for name in tagNames {
            let commitHash = (try? Shell.runSync(tagCommitHashCommand(name), at: path)) ?? ""
            let tagInfo = (try? Shell.runSync(tagInfoCommand(name), at: path)) ?? "::"
            let parts = tagInfo.split(separator: "::").map { String($0) }
            let author = parts.count > 0 ? parts[0] : nil
            let date = parts.count > 1 ? ISO8601DateFormatter().date(from: parts[1]) : nil
            let message = parts.count > 2 ? parts[2] : nil
            tags.append(MagicGitTag(id: name, name: name, commitHash: commitHash, author: author, date: date, message: message))
        }
        return tags
    }

    static func createTagCommand(_ name: String, message: String? = nil) -> String {
        if let message {
            return "git tag -a \(shellQuoted(name)) -m \(shellQuoted(message))"
        } else {
            return "git tag \(shellQuoted(name))"
        }
    }

    static func deleteTagCommand(_ name: String) -> String {
        "git tag -d \(shellQuoted(name))"
    }

    static func tagsForCommitCommand(_ commit: String) -> String {
        "git tag --points-at \(shellQuoted(commit))"
    }

    static func tagCommitHashCommand(_ name: String) -> String {
        "git rev-list -n 1 \(shellQuoted(name))"
    }

    static func tagInfoCommand(_ name: String) -> String {
        "git for-each-ref \(shellQuoted("refs/tags/\(name)")) --format='%(taggername)::%(taggerdate)::%(subject)'"
    }
}
#endif

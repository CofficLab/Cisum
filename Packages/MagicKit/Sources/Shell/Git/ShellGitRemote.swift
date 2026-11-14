import Foundation
import OSLog
import SwiftUI
#if os(macOS)
extension ShellGit {
    /// 推送到远程仓库
    /// - Parameters:
    ///   - remote: 远程仓库名称，默认为origin
    ///   - branch: 分支名称，默认为当前分支
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    @discardableResult
    public static func push(remote: String = "origin", branch: String? = nil, at path: String? = nil) throws -> String {
        return try Shell.runSync(pushCommand(remote: remote, branch: branch), at: path)
    }

    static func pushCommand(remote: String = "origin", branch: String? = nil) -> String {
        if let branch {
            "git push \(shellQuoted(remote)) \(shellQuoted(branch))"
        } else {
            "git push \(shellQuoted(remote))"
        }
    }
    
    /// 从远程仓库拉取
    /// - Parameters:
    ///   - remote: 远程仓库名称，默认为origin
    ///   - branch: 分支名称，默认为当前分支
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    @discardableResult
    public static func pull(remote: String = "origin", branch: String? = nil, at path: String? = nil) throws -> String {
        return try Shell.runSync(pullCommand(remote: remote, branch: branch), at: path)
    }

    static func pullCommand(remote: String = "origin", branch: String? = nil) -> String {
        if let branch {
            "git pull \(shellQuoted(remote)) \(shellQuoted(branch))"
        } else {
            "git pull \(shellQuoted(remote))"
        }
    }
    
    /// 添加远程仓库
    /// - Parameters:
    ///   - name: 远程仓库名称
    ///   - url: 远程仓库URL
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func addRemote(_ name: String, url: String, at path: String? = nil) throws -> String {
        return try Shell.runSync(addRemoteCommand(name, url: url), at: path)
    }

    static func addRemoteCommand(_ name: String, url: String) -> String {
        "git remote add \(shellQuoted(name)) \(shellQuoted(url))"
    }
    
    /// 获取远程仓库列表
    /// - Parameters:
    ///   - verbose: 是否显示详细信息
    ///   - path: 仓库路径
    /// - Returns: 远程仓库列表，字符串形式
    public static func remotes(verbose: Bool = false, at path: String? = nil) throws -> String {
        let option = verbose ? "-v" : ""
        return try Shell.runSync("git remote \(option)", at: path)
    }

    /// 获取远程仓库列表-数组
    /// - Parameters:
    ///   - verbose: 是否显示详细信息
    ///   - path: 仓库路径
    /// - Returns: 远程仓库列表，字符串数组形式
    public static func remotesArray(verbose: Bool = false, at path: String? = nil) throws -> [String] {
        let output = try remotes(verbose: verbose, at: path)
        return output.split(separator: "\n").map { String($0) }
    }

    /// 获取第一个远程仓库的URL
    /// - Parameter path: 仓库路径
    /// - Returns: 第一个远程仓库的URL，如果不存在则返回nil
    public static func firstRemoteURL(at path: String? = nil) throws -> String? {
        let output = try Shell.runSync("git remote -v", at: path)
        return parseFirstRemoteURL(output)
    }
    
    /// 删除远程仓库
    /// - Parameters:
    ///   - name: 远程仓库名称
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func removeRemote(_ name: String, at path: String? = nil) throws -> String {
        return try Shell.runSync(removeRemoteCommand(name), at: path)
    }

    static func removeRemoteCommand(_ name: String) -> String {
        "git remote remove \(shellQuoted(name))"
    }

    /// 修改远程仓库URL
    /// - Parameters:
    ///   - name: 远程仓库名称
    ///   - url: 新的远程仓库URL
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func setRemoteURL(_ name: String, url: String, at path: String? = nil) throws -> String {
        return try Shell.runSync(setRemoteURLCommand(name, url: url), at: path)
    }

    static func setRemoteURLCommand(_ name: String, url: String) -> String {
        "git remote set-url \(shellQuoted(name)) \(shellQuoted(url))"
    }

    /// 获取远程结构体列表
    /// - Parameters:
    ///   - path: 仓库路径
    /// - Returns: 远程结构体数组
    public static func remoteList(at path: String? = nil) throws -> [MagicGitRemote] {
        let output = try remotes(verbose: true, at: path)
        return parseRemoteListOutput(output)
    }

    static func parseRemoteListOutput(_ output: String) -> [MagicGitRemote] {
        let lines = output.split(separator: "\n").map { String($0) }
        var remotes: [MagicGitRemote] = []
        for line in lines {
            guard let row = parseRemoteVerboseLine(line) else { continue }
            let name = row.name
            let url = row.url
            let type = row.type
            var fetchURL: String? = nil
            var pushURL: String? = nil
            if type == "fetch" { fetchURL = url }
            if type == "push" { pushURL = url }
            if let idx = remotes.firstIndex(where: { $0.name == name }) {
                // 已有，补充 push/fetch
                if fetchURL != nil { remotes[idx] = MagicGitRemote(id: name, name: name, url: remotes[idx].url, fetchURL: fetchURL, pushURL: remotes[idx].pushURL, isDefault: idx == 0) }
                if pushURL != nil { remotes[idx] = MagicGitRemote(id: name, name: name, url: remotes[idx].url, fetchURL: remotes[idx].fetchURL, pushURL: pushURL, isDefault: idx == 0) }
            } else {
                remotes.append(MagicGitRemote(id: name, name: name, url: url, fetchURL: fetchURL, pushURL: pushURL, isDefault: remotes.isEmpty))
            }
        }
        return remotes
    }

    static func parseFirstRemoteURL(_ output: String) -> String? {
        output
            .split(separator: "\n")
            .compactMap { parseRemoteVerboseLine(String($0))?.url }
            .first
    }

    static func parseRemoteVerboseLine(_ line: String) -> (name: String, url: String, type: String)? {
        let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false).map { String($0) }
        guard parts.count == 2, !parts[0].isEmpty else { return nil }

        let suffixes = [(" (fetch)", "fetch"), (" (push)", "push")]
        guard let suffix = suffixes.first(where: { parts[1].hasSuffix($0.0) }) else { return nil }

        let url = String(parts[1].dropLast(suffix.0.count))
        guard !url.isEmpty else { return nil }

        return (name: parts[0], url: url, type: suffix.1)
    }
}
#endif

import Foundation
import OSLog
import SwiftUI
#if os(macOS)
extension ShellGit {
    /// 获取提交日志
    /// - Parameters:
    ///   - limit: 限制条数
    ///   - oneline: 是否单行显示
    ///   - path: 仓库路径
    /// - Returns: 日志信息
    public static func log(limit: Int = 10, oneline: Bool = true, at path: String? = nil) throws -> String {
        return try Shell.runSync(logCommand(limit: limit, oneline: oneline), at: path)
    }
    
    /// 获取提交日志（字符串数组）
    /// - Parameters:
    ///   - limit: 限制条数
    ///   - oneline: 是否单行显示
    ///   - path: 仓库路径
    /// - Returns: 日志信息数组
    public static func logArray(limit: Int = 10, oneline: Bool = true, at path: String? = nil) throws -> [String] {
        let logString = try log(limit: limit, oneline: oneline, at: path)
        return logString.split(separator: "\n").map { String($0) }
    }
    
    /// 获取最近的提交记录
    /// - Parameters:
    ///   - count: 获取的提交数量
    ///   - path: 仓库路径
    /// - Returns: 提交记录列表
    public static func recentCommits(count: Int = 10, at path: String? = nil) throws -> [MagicGitCommit] {
        let format = "%H%x01%an%x01%ae%x01%at%x01%s"
        let output = try Shell.runSync(recentCommitsCommand(count: count, format: format), at: path)
        return output.split(separator: "\n").compactMap { line in
            parseRecentCommitLine(String(line))
        }
    }
    
    /// 获取指定分支的提交记录
    /// - Parameters:
    ///   - branch: 分支名称
    ///   - count: 获取的提交数量
    ///   - path: 仓库路径
    /// - Returns: 提交记录列表
    public static func commits(in branch: String, count: Int = 10, at path: String? = nil) throws -> [MagicGitCommit] {
        let format = "%H%x01%an%x01%ae%x01%at%x01%s"
        let output = try Shell.runSync(commitsInBranchCommand(branch, count: count, format: format), at: path)
        return output.split(separator: "\n").compactMap { line in
            parseRecentCommitLine(String(line))
        }
    }
    
    /// 获取提交的详细信息
    /// - Parameters:
    ///   - commit: 提交哈希
    ///   - path: 仓库路径
    /// - Returns: 提交详细信息
    public static func commitDetail(_ commit: String, at path: String? = nil) async throws -> MagicGitCommitDetail {
        let format = "%H%x01%an%x01%ae%x01%at%x01%s%x01%b"
        let output = try Shell.runSync(commitDetailCommand(commit, format: format), at: path)
        let parsedCommit = try parseCommitDetailOutput(output)
        
        let files = try await changedFilesDetail(in: commit, at: path)
        let diff = try Shell.runSync(commitShowCommand(commit), at: path)
        
        return MagicGitCommitDetail(
            id: parsedCommit.id,
            author: parsedCommit.author,
            email: parsedCommit.email,
            date: parsedCommit.date,
            message: parsedCommit.message,
            body: parsedCommit.body,
            files: files,
            diff: diff
        )
    }

    static func parseRecentCommitLine(_ line: String) -> MagicGitCommit? {
        let separator = line.contains("\u{01}") ? "\u{01}" : "|"
        let parts = line.split(separator: Character(separator), maxSplits: 4, omittingEmptySubsequences: false).map { String($0) }
        guard parts.count == 5 else { return nil }
        guard let date = parseUnixTimestamp(parts[3]) else { return nil }
        return MagicGitCommit(
            id: parts[0],
            hash: parts[0],
            author: parts[1],
            email: parts[2],
            date: date,
            message: parts[4],
            body: "",
            refs: [],
            tags: []
        )
    }

    static func parseCommitDetailOutput(_ output: String) throws -> MagicGitCommitDetail {
        let separator = output.contains("\u{01}") ? "\u{01}" : "|"
        let parts = output.split(separator: Character(separator), maxSplits: 5, omittingEmptySubsequences: false).map { String($0) }
        guard parts.count == 6 else {
            throw NSError(domain: "ShellGit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid commit format"])
        }
        guard let date = parseUnixTimestamp(parts[3]) else {
            throw NSError(domain: "ShellGit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid commit timestamp"])
        }

        return MagicGitCommitDetail(
            id: parts[0],
            author: parts[1],
            email: parts[2],
            date: date,
            message: parts[4],
            body: parts[5],
            files: [],
            diff: ""
        )
    }

    private static func parseUnixTimestamp(_ rawValue: String) -> Date? {
        guard let seconds = TimeInterval(rawValue), seconds.isFinite else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    static func parseISO8601CommitDate(_ rawValue: String) -> Date? {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        return dateFormatter.date(from: rawValue)
    }
    
    /// 获取本地未推送到远程的提交日志
    /// - Parameters:
    ///   - remote: 远程仓库名，默认 origin
    ///   - branch: 分支名，默认当前分支
    ///   - path: 仓库路径
    /// - Returns: 未推送的提交日志（字符串数组）
    public static func unpushedCommits(remote: String = "origin", branch: String? = nil, at path: String? = nil) throws -> [String] {
        let branchName: String
        if let branch = branch {
            branchName = branch
        } else {
            branchName = try currentBranch(at: path)
        }
        let log = try Shell.runSync(unpushedCommitsCommand(remote: remote, branchName: branchName), at: path)
        return log.split(separator: "\n").map { String($0) }
    }

    /// 获取提交及其标签列表
    /// - Parameters:
    ///   - limit: 限制条数
    ///   - at: 仓库路径
    /// - Returns: [CommitWithTag]
    public static func commitsWithTags(limit: Int = 20, at path: String? = nil) throws -> [CommitWithTag] {
        // 使用 git log --pretty=format:"%H%x09%s%x09%d" 获取 hash、message、ref
        let log = try Shell.runSync(commitsWithTagsCommand(limit: limit), at: path)
        return log.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 3 else { return nil }
            let hash = String(parts[0])
            let message = String(parts[1])
            let ref = String(parts[2])
            // 提取 tag 名称
            let tags = parseDecorationTags(ref)
            return CommitWithTag(hash: hash, message: message, tags: tags)
        }
    }

    /// 分页获取提交日志
    /// - Parameters:
    ///   - page: 页码（从 0 开始，0表示第一页）
    ///   - size: 每页条数
    ///   - oneline: 是否单行显示
    ///   - path: 仓库路径
    /// - Returns: 日志信息数组
    public static func logsWithPagination(page: Int = 0, size: Int = 20, oneline: Bool = true, at path: String? = nil) throws -> [String] {
        guard page >= 0 else {
            throw NSError(domain: "ShellGit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Page number must be non-negative"])
        }
        let pagination = paginationArguments(page: page, size: size)
        let log = try Shell.runSync(logsWithPaginationCommand(skip: pagination.skip, size: pagination.size, oneline: oneline), at: path)
        return log.split(separator: "\n").map { String($0) }
    }

    /// 获取提交记录结构体列表
    /// - Parameters:
    ///   - limit: 限制条数
    ///   - at: 仓库路径
    /// - Returns: [MagicGitCommit]
    public static func commitList(limit: Int = 20, at path: String? = nil) throws -> [MagicGitCommit] {
        // 使用 SOH (Start of Header, ASCII 0x01) 作为字段分隔符，避免 body 中的换行符破坏格式
        // 使用 null byte (ASCII 0x00) 作为记录分隔符，因为 git log format 不支持空字节，但我们可以用特殊字符替代
        let format = "%H%x01%an%x01%ae%x01%cI%x01%s%x01%b%x01%d%x02"
        // 使用 --pretty=tformat 确保每条记录后都有分隔符
        let log = try Shell.runSync(commitListCommand(limit: limit, format: format), at: path)
        // 使用 STX (Start of Text, ASCII 0x02) 作为记录分隔符
        return log.split(separator: "\u{02}", omittingEmptySubsequences: false).compactMap { record in
            let trimmedRecord = record.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedRecord.isEmpty else { return nil }

            // 使用 SOH 作为字段分隔符
            let parts = trimmedRecord.split(separator: "\u{01}", omittingEmptySubsequences: false)
            guard parts.count >= 7 else { return nil }

            let hash = String(parts[0])
            let author = String(parts[1])
            let email = String(parts[2])
            let dateStr = String(parts[3])
            let message = String(parts[4])
            let body = String(parts[5])
            let refs = String(parts[6])

            guard let date = parseISO8601CommitDate(dateStr) else { return nil }

            let tags = parseDecorationTags(refs)
            let refArray = refs.components(separatedBy: ", ").filter{!$0.isEmpty}

            return MagicGitCommit(id: hash, hash: hash, author: author, email: email, date: date, message: message, body: body, refs: refArray, tags: tags)
        }
    }

    /// 获取本地未推送到远程的提交日志（结构体版）
    /// - Parameters:
    ///   - remote: 远程仓库名，默认 origin
    ///   - branch: 分支名，默认当前分支
    ///   - path: 仓库路径
    /// - Returns: 未推送的提交日志（[MagicGitCommit]）
    public static func unpushedCommitList(remote: String = "origin", branch: String? = nil, at path: String? = nil) throws -> [MagicGitCommit] {
        let branchName: String
        if let branch = branch {
            branchName = branch
        } else {
            branchName = try currentBranch(at: path)
        }
        let log = try Shell.runSync(unpushedCommitListCommand(remote: remote, branchName: branchName), at: path)
        let lines = log.split(separator: "\n").map { String($0) }
        var commits: [MagicGitCommit] = []
        for line in lines {
            let parts = line.split(separator: "\t").map { String($0) }
            guard parts.count >= 5 else { continue }
            let hash = parts[0]
            let author = parts[1]
            let email = parts[2]
            let dateStr = parts[3]
            let message = parts[4]
            let refs = parts.count > 5 ? parts[5].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } : []
            let tags = refs.filter { $0.contains("tag:") }.map { $0.replacingOccurrences(of: "tag:", with: "").trimmingCharacters(in: .whitespaces) }
            guard let date = parseISO8601CommitDate(dateStr) else { continue }
            commits.append(MagicGitCommit(id: hash, hash: hash, author: author, email: email, date: date, message: message, refs: refs, tags: tags))
        }
        return commits
    }

    static func commitsInBranchCommand(_ branch: String, count: Int, format: String) -> String {
        "git log \(shellQuoted(branch)) -n \(normalizedLimit(count)) --pretty=format:\(shellQuoted(format))"
    }

    static func recentCommitsCommand(count: Int, format: String) -> String {
        "git log -n \(normalizedLimit(count)) --pretty=format:\(shellQuoted(format))"
    }

    static func commitsWithTagsCommand(limit: Int) -> String {
        "git log --pretty=format:\(shellQuoted("%H%x09%s%x09%d")) -\(normalizedLimit(limit))"
    }

    static func commitListCommand(limit: Int, format: String) -> String {
        "git log --pretty=tformat:\(shellQuoted(format)) -n \(normalizedLimit(limit))"
    }

    static func logCommand(limit: Int, oneline: Bool) -> String {
        let format = oneline ? "--oneline " : ""
        return "git log \(format)-\(normalizedLimit(limit))"
    }

    static func logsWithPaginationCommand(skip: Int, size: Int, oneline: Bool) -> String {
        let format = oneline ? "--oneline " : ""
        return "git log \(format)--skip=\(max(0, skip)) -\(normalizedLimit(size))"
    }

    static func commitDetailCommand(_ commit: String, format: String) -> String {
        "git show \(shellQuoted(commit)) --pretty=format:\(shellQuoted(format)) --no-patch"
    }

    static func commitShowCommand(_ commit: String) -> String {
        "git show \(shellQuoted(commit))"
    }

    static func unpushedCommitsCommand(remote: String, branchName: String) -> String {
        "git log \(shellQuoted("\(remote)/\(branchName)..\(branchName)")) --oneline"
    }

    static func unpushedCommitListCommand(remote: String, branchName: String) -> String {
        let format = "%H%x09%an%x09%ae%x09%ad%x09%s%x09%D"
        return "git log \(shellQuoted("\(remote)/\(branchName)..\(branchName)")) --pretty=format:\(shellQuoted(format))"
    }

    /// 分页获取提交日志（结构体版）
    /// - Parameters:
    ///   - page: 页码（从 0 开始，0表示第一页）
    ///   - size: 每页条数
    ///   - at: 仓库路径
    /// - Returns: [MagicGitCommit]
    public static func commitListWithPagination(page: Int = 0, size: Int = 20, at path: String? = nil) throws -> [MagicGitCommit] {
        guard page >= 0 else {
            throw NSError(domain: "ShellGit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Page number must be non-negative"])
        }

        let pagination = paginationArguments(page: page, size: size)
        // 使用 SOH (Start of Header, ASCII 0x01) 作为字段分隔符，避免 body 中的换行符破坏格式
        // 使用 STX (Start of Text, ASCII 0x02) 作为记录分隔符
        let format = "%H%x01%an%x01%ae%x01%cI%x01%s%x01%b%x01%d%x02"
        let log = try Shell.runSync(commitListWithPaginationCommand(skip: pagination.skip, size: pagination.size, format: format), at: path)
        // 使用 STX (Start of Text, ASCII 0x02) 作为记录分隔符
        return log.split(separator: "\u{02}", omittingEmptySubsequences: false).compactMap { record in
            let trimmedRecord = record.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedRecord.isEmpty else { return nil }

            // 使用 SOH 作为字段分隔符
            let parts = trimmedRecord.split(separator: "\u{01}", omittingEmptySubsequences: false)
            guard parts.count >= 7 else { return nil }

            let hash = String(parts[0])
            let author = String(parts[1])
            let email = String(parts[2])
            guard let date = parseISO8601CommitDate(String(parts[3])) else { return nil }
            let message = String(parts[4])
            let body = String(parts[5])
            let refs = String(parts[6])
            let tags = parseDecorationTags(refs)
            return MagicGitCommit(id: hash, hash: hash, author: author, email: email, date: date, message: message, body: body, refs: refs.components(separatedBy: ", ").filter{!$0.isEmpty}, tags: tags)
        }
    }

    static func parseDecorationTags(_ refs: String) -> [String] {
        let trimmed = refs
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "()"))

        guard !trimmed.isEmpty else { return [] }

        return trimmed
            .components(separatedBy: ", ")
            .compactMap { ref in
                let marker = "tag: "
                guard ref.hasPrefix(marker) else { return nil }
                let tag = String(ref.dropFirst(marker.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                return tag.isEmpty ? nil : tag
            }
    }

    static func commitListWithPaginationCommand(skip: Int, size: Int, format: String) -> String {
        "git log --pretty=tformat:\(shellQuoted(format)) --skip=\(max(0, skip)) -n \(normalizedLimit(size))"
    }

    static func normalizedLimit(_ value: Int) -> Int {
        max(0, value)
    }

    static func paginationArguments(page: Int, size: Int) -> (skip: Int, size: Int) {
        let normalizedSize = normalizedLimit(size)
        let multiplication = page.multipliedReportingOverflow(by: normalizedSize)
        let skip = multiplication.overflow ? Int.max : multiplication.partialValue
        return (skip: max(0, skip), size: normalizedSize)
    }
}

#endif

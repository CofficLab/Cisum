import Foundation
import OSLog
import SwiftUI
#if os(macOS)
extension ShellGit {
    /// 获取差异
    /// - Parameters:
    ///   - staged: 是否查看暂存区差异
    ///   - path: 仓库路径
    /// - Returns: 差异信息
    public static func diff(staged: Bool = false, at path: String? = nil) throws -> String {
        let option = staged ? "--cached" : ""
        return try Shell.runSync("git diff \(option)", at: path)
    }
    
    /// 获取文件差异
    /// - Parameters:
    ///   - file: 文件路径
    ///   - staged: 是否查看暂存区差异
    ///   - path: 仓库路径
    /// - Returns: 文件差异信息
    public static func diffFile(_ file: String, staged: Bool = false, at path: String? = nil) throws -> String {
        let option = staged ? "--cached" : ""
        return try Shell.runSync("git diff \(option) -- \(shellQuoted(file))", at: path)
    }
    
    /// 获取两个提交之间的差异
    /// - Parameters:
    ///   - from: 起始提交
    ///   - to: 目标提交
    ///   - path: 仓库路径
    /// - Returns: 差异信息
    public static func diffBetweenCommits(from: String, to: String, at path: String? = nil) throws -> String {
        return try Shell.runSync(diffBetweenCommitsCommand(from: from, to: to), at: path)
    }
    
    /// 检查文件在指定commit中是否存在
    /// - Parameters:
    ///   - commit: commit哈希
    ///   - file: 文件路径
    ///   - repoPath: 仓库路径
    /// - Returns: 文件是否存在
    private static func fileExists(at commit: String, file: String, repoPath: String) -> Bool {
        do {
            _ = try Shell.runSync(fileExistsCommand(commit: commit, file: file), at: repoPath)
            return true
        } catch {
            return false
        }
    }
    
    /// 获取某个 commit 前后的文件内容
    /// - Parameters:
    ///   - commit: commit 哈希
    ///   - file: 文件路径（相对仓库根目录）
    ///   - repoPath: 仓库本地路径
    /// - Returns: (修改前内容, 修改后内容)
    ///   - before: 父commit中的文件内容，如果文件在父commit中不存在则为nil
    ///   - after: 当前commit中的文件内容，如果文件在当前commit中不存在则为nil
    /// - Note:
    ///   - 如果文件是新增的：before为nil，after为文件内容
    ///   - 如果文件是删除的：before为文件内容，after为nil
    ///   - 如果文件是修改的：before和after都为文件内容
    ///   - 如果文件在两个commit中都不存在：before和after都为nil
    public static func fileContentChange(at commit: String, file: String, repoPath: String) throws -> (before: String?, after: String?) {
        // 检查是否为初始commit（没有父commit）
        let hasParent: Bool
        do {
            _ = try Shell.runSync(parentCommitCommand(commit), at: repoPath)
            hasParent = true
        } catch {
            hasParent = false
        }

        let before: String?
        if hasParent {
            // 获取 parent commit
            let parentCommit = try Shell.runSync(parentCommitCommand(commit), at: repoPath).trimmingCharacters(in: .whitespacesAndNewlines)

            // 先检查文件是否存在，再获取内容
            before = fileExists(at: parentCommit, file: file, repoPath: repoPath)
                ? try Shell.runSync(fileContentCommand(commit: parentCommit, file: file), at: repoPath)
                : nil
        } else {
            // 初始commit没有父commit，所以before为nil
            before = nil
        }

        let after: String? = fileExists(at: commit, file: file, repoPath: repoPath)
            ? try Shell.runSync(fileContentCommand(commit: commit, file: file), at: repoPath)
            : nil

        return (before, after)
    }
    
    /// 获取指定 commit 下的文件内容
    /// - Parameters:
    ///   - file: 文件路径（相对仓库根目录）
    ///   - commit: commit 哈希（如 HEAD, HEAD~1, 某个具体 hash）
    ///   - path: 仓库路径
    /// - Returns: 文件内容字符串
    public static func fileContent(atCommit commit: String, file: String, at path: String? = nil) throws -> String {
        return try Shell.runSync(fileContentCommand(commit: commit, file: file), at: path)
    }
    
    /// 获取当前工作区的文件内容
    /// - Parameters:
    ///   - file: 文件路径（相对仓库根目录）
    ///   - path: 仓库路径
    /// - Returns: 文件内容字符串
    public static func fileContentInWorkingDirectory(file: String, at path: String? = nil) throws -> String {
        let repoPath = path ?? FileManager.default.currentDirectoryPath
        let fileURL = try workingDirectoryFileURL(file: file, repoPath: repoPath)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }
    
    /// 获取所有变动文件及其 diff 内容（结构体版）
    /// - Parameters:
    ///   - staged: 是否查看暂存区差异
    ///   - path: 仓库路径
    /// - Returns: [MagicGitDiffFile]
    public static func diffFileList(staged: Bool = false, at path: String? = nil) async throws -> [MagicGitDiffFile] {
        let option = staged ? "--cached" : ""
        // 获取变动文件及类型
        let nameStatus = try Shell.runSync("git diff --name-status -z \(option)", at: path)
        let files = parseNameStatusZOutput(nameStatus)
        var result: [MagicGitDiffFile] = []
        for parsedFile in files {
            let changeType = parsedFile.changeType
            let file = parsedFile.file
            let diff = try Shell.runSync("git diff \(option) -- \(shellQuoted(file))", at: path)
            result.append(MagicGitDiffFile(id: file, file: file, changeType: changeType, diff: diff))
        }
        return result
    }
    
    /// 获取指定 commit 涉及的所有文件变动及 diff 内容（结构体版）
    /// - Parameters:
    ///   - commit: commit 哈希
    ///   - path: 仓库路径
    /// - Returns: [MagicGitDiffFile]
    public static func fileChanges(in commit: String, at path: String? = nil) throws -> [MagicGitDiffFile] {
        let nameStatus = try Shell.runSync(diffTreeNameStatusCommand(commit), at: path)
        let files = parseNameStatusZOutput(nameStatus)
        var result: [MagicGitDiffFile] = []
        for parsedFile in files {
            let changeType = parsedFile.changeType
            let file = parsedFile.file
            let diff = try Shell.runSync(showCommitFileDiffCommand(commit: commit, file: file), at: path)
            result.append(MagicGitDiffFile(id: file, file: file, changeType: changeType, diff: diff))
        }
        return result
    }
    
    /// 获取指定 commit 变动的文件名列表
    /// - Parameters:
    ///   - commit: commit 哈希
    ///   - path: 仓库路径
    /// - Returns: 文件名数组
    public static func changedFiles(in commit: String, at path: String? = nil) throws -> [String] {
        let output = try Shell.runSync(diffTreeNameOnlyCommand(commit), at: path)
        return parsePathZOutput(output)
    }
    
    /// 获取指定 commit 变动的文件列表（结构体版）
    /// - Parameters:
    ///   - commit: commit 哈希
    ///   - path: 仓库路径
    ///   - verbose: 是否详细输出，默认不详细输出
    /// - Returns: [MagicGitDiffFile]，仅包含文件名和变动类型，diff 为空
    public static func changedFilesDetail(in commit: String, at path: String? = nil, verbose: Bool = false) async throws -> [MagicGitDiffFile] {
        // 检查是否为初始commit（没有父commit）
        // 使用 rev-list --parents 获取commit及其父commit信息
        let revListOutput = try await Shell.run(revListParentsCommand(commit), at: path, verbose: false)
        let parts = revListOutput.split(separator: " ").map { String($0) }
        let hasParent = parts.count > 1 // 如果有父commit，parts会包含多个元素

        if hasParent {
            // 有父commit，使用diff-tree获取变更文件
            let output = try await Shell.run(diffTreeNameStatusCommand(commit), at: path, verbose: verbose)
            let files = parseNameStatusZOutput(output)
            return files.map { parsedFile in
                let changeType = parsedFile.changeType
                let file = parsedFile.file
                return MagicGitDiffFile(id: file, file: file, changeType: changeType, diff: "")
            }
        } else {
            // 初始commit，使用show --name-only获取所有文件
            let output = try await Shell.run(showNameOnlyCommand(commit), at: path, verbose: verbose)
            let lines = output.split(separator: "\n").map { String($0) }
            // 跳过commit信息行，获取文件列表
            let fileLines = lines.dropFirst()
            return fileLines.compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                // 对于初始commit，所有文件都是新增的（A = Added）
                return MagicGitDiffFile(id: trimmed, file: trimmed, changeType: "A", diff: "")
            }
        }
    }

    /// 获取未提交文件的变动前后内容
    /// - Parameters:
    ///   - file: 文件路径（相对仓库根目录）
    ///   - repoPath: 仓库本地路径
    /// - Returns: (修改前内容, 修改后内容)
    /// - Throws: 如果无法读取文件内容则抛出错误
    public static func uncommittedFileContentChange(file: String, repoPath: String) throws -> (before: String?, after: String?) {
        // 获取 HEAD 中的文件内容（修改前）
        // 如果文件在 HEAD 中不存在（新文件），则 before 为 nil
        let before: String?
        do {
            before = try Shell.runSync(fileContentCommand(commit: "HEAD", file: file), at: repoPath)
        } catch {
            // 文件在 HEAD 中不存在，可能是新文件
            before = nil
        }
        
        // 获取工作区中的文件内容（修改后）
        let after: String?
        do {
            let fileURL = try workingDirectoryFileURL(file: file, repoPath: repoPath)
            after = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            // 文件在工作区中不存在，可能是删除的文件
            after = nil
        }
        
        return (before, after)
    }
    
    /// 检查是否有文件待提交（暂存区是否有内容）
    /// - Parameter path: 仓库路径
    /// - Returns: 是否有文件待提交
    public static func hasFilesToCommit(at path: String? = nil) throws -> Bool {
        let output = try Shell.runSync("git diff --cached --name-only", at: path)
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func diffBetweenCommitsCommand(from: String, to: String) -> String {
        "git diff \(shellQuoted(from)) \(shellQuoted(to))"
    }

    static func fileExistsCommand(commit: String, file: String) -> String {
        "git cat-file -e \(shellQuoted("\(commit):\(file)"))"
    }

    static func parentCommitCommand(_ commit: String) -> String {
        "git rev-parse \(shellQuoted("\(commit)^"))"
    }

    static func fileContentCommand(commit: String, file: String) -> String {
        "git show \(shellQuoted("\(commit):\(file)"))"
    }

    static func diffTreeNameStatusCommand(_ commit: String) -> String {
        "git diff-tree --no-commit-id --name-status -z -r \(shellQuoted(commit))"
    }

    static func diffTreeNameOnlyCommand(_ commit: String) -> String {
        "git diff-tree --no-commit-id --name-only -z -r \(shellQuoted(commit))"
    }

    static func revListParentsCommand(_ commit: String) -> String {
        "git rev-list --parents -n 1 \(shellQuoted(commit))"
    }

    static func showCommitFileDiffCommand(commit: String, file: String) -> String {
        "git show \(shellQuoted(commit)) -- \(shellQuoted(file))"
    }

    static func showNameOnlyCommand(_ commit: String) -> String {
        "git show --name-only --format= \(shellQuoted(commit))"
    }

    static func workingDirectoryFileURL(file: String, repoPath: String) throws -> URL {
        guard !file.isEmpty, !file.hasPrefix("/") else {
            throw NSError(
                domain: "ShellGitDiff",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "File path must be relative to repository working directory"]
            )
        }

        let baseURL = URL(fileURLWithPath: repoPath, isDirectory: true).standardizedFileURL
        let fileURL = baseURL.appendingPathComponent(file).standardizedFileURL
        let basePath = baseURL.path
        let filePath = fileURL.path

        guard filePath == basePath || filePath.hasPrefix(basePath + "/") else {
            throw NSError(
                domain: "ShellGitDiff",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "File path escapes repository working directory"]
            )
        }

        return fileURL
    }

    static func parseNameStatusLine(_ line: String) -> (changeType: String, file: String)? {
        let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map { String($0) }
        guard parts.count >= 2, !parts[0].isEmpty else { return nil }

        let changeType = parts[0]
        let file: String
        if changeType.hasPrefix("R") || changeType.hasPrefix("C") {
            guard let newPath = parts.last, !newPath.isEmpty else { return nil }
            file = newPath
        } else {
            guard !parts[1].isEmpty else { return nil }
            file = parts[1]
        }

        return (changeType, file)
    }

    static func parseNameStatusZOutput(_ output: String) -> [(changeType: String, file: String)] {
        let records = output.split(separator: "\0", omittingEmptySubsequences: false).map(String.init)
        var files: [(changeType: String, file: String)] = []
        var index = 0

        while index < records.count {
            let changeType = records[index]
            guard !changeType.isEmpty else {
                index += 1
                continue
            }

            if changeType.hasPrefix("R") || changeType.hasPrefix("C") {
                guard index + 2 < records.count, !records[index + 2].isEmpty else { break }
                files.append((changeType: changeType, file: records[index + 2]))
                index += 3
            } else {
                guard index + 1 < records.count, !records[index + 1].isEmpty else { break }
                files.append((changeType: changeType, file: records[index + 1]))
                index += 2
            }
        }

        return files
    }

    static func parsePathZOutput(_ output: String) -> [String] {
        output.split(separator: "\0").map(String.init)
    }

    static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
#endif

import Foundation
import OSLog
import SwiftUI

#if os(macOS)
extension ShellGit {
    /// 获取暂存区的状态
    /// - Parameter path: 仓库路径
    /// - Returns: 暂存区状态信息
    public static func status(at path: String? = nil) throws -> String {
        return try Shell.runSync("git status", at: path)
    }
    
    /// 获取简洁的状态信息
    /// - Parameter path: 仓库路径
    /// - Returns: 简洁的状态信息
    public static func statusPorcelain(at path: String? = nil) throws -> String {
        return try Shell.runSync("git status --porcelain", at: path)
    }
    
    /// 获取暂存区文件列表
    /// - Parameter path: 仓库路径
    /// - Returns: 暂存区文件列表
    public static func stagedFiles(at path: String? = nil) throws -> [String] {
        let output = try Shell.runSync("git diff --cached --name-only -z", at: path)
        return output.split(separator: "\0").map { String($0) }
    }
    
    /// 获取未暂存的文件列表
    /// - Parameter path: 仓库路径
    /// - Returns: 未暂存的文件列表
    public static func unstagedFiles(at path: String? = nil) throws -> [String] {
        let output = try Shell.runSync("git status --porcelain -z --untracked-files=all", at: path)
        return parseUnstagedFiles(fromPorcelainZOutput: output)
    }
    
    /// 判断本地是否有未提交的变动
    /// - Parameter path: 仓库路径
    /// - Returns: 如果有未提交的变动则返回true，否则返回false
    public static func hasUncommittedChanges(at path: String? = nil) throws -> Bool {
        let output = try statusPorcelain(at: path)
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func parseUnstagedFile(fromPorcelainLine line: String) -> String? {
        guard line.count >= 4 else { return nil }
        let status = String(line.prefix(2))
        let path = String(line.dropFirst(3))
        guard !path.isEmpty else { return nil }

        if status == "??" {
            return path
        }

        guard let worktreeStatus = status.last, worktreeStatus != " " else {
            return nil
        }

        return pathAfterRenameMarker(path)
    }

    static func parseUnstagedFiles(fromPorcelainZOutput output: String) -> [String] {
        let records = output.split(separator: "\0").map(String.init)
        var files: [String] = []
        var index = 0

        while index < records.count {
            let record = records[index]
            if let file = parseUnstagedFile(fromPorcelainLine: record) {
                files.append(file)
            }

            if isRenameOrCopyPorcelainRecord(record) {
                index += 1
            }

            index += 1
        }

        return files
    }

    private static func isRenameOrCopyPorcelainRecord(_ record: String) -> Bool {
        record.prefix(2).contains("R") || record.prefix(2).contains("C")
    }

    private static func pathAfterRenameMarker(_ path: String) -> String {
        path.components(separatedBy: " -> ").last ?? path
    }
}
#endif

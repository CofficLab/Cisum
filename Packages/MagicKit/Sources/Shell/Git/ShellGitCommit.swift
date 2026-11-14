import Foundation
import OSLog
import SwiftUI

#if os(macOS)
extension ShellGit {
    /// 提交暂存区的变更
    /// - Parameters:
    ///   - message: 提交信息
    ///   - path: 仓库路径
    /// - Returns: 提交的哈希值
    @discardableResult
    public static func commit(message: String, at path: String? = nil) throws -> String {
        // 执行提交
        _ = try Shell.runSync("git commit -m \(shellQuoted(message))", at: path)
        // 直接获取 HEAD 哈希，这是最可靠的方式
        let headHash = try Shell.runSync("git rev-parse HEAD", at: path)
        return headHash.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 添加并提交文件
    /// - Parameters:
    ///   - files: 要提交的文件路径数组，为空则提交所有文件
    ///   - message: 提交信息
    ///   - path: 仓库路径
    /// - Returns: 提交的哈希值
    @discardableResult
    public static func addAndCommit(files: [String] = [], message: String, at path: String? = nil) throws -> String {
        try add(files, at: path)
        return try commit(message: message, at: path)
    }
}
#endif

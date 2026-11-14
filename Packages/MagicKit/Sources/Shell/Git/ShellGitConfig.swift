import Foundation
import OSLog
import SwiftUI
#if os(macOS)
extension ShellGit {
    /// 检查是否为Git仓库
    /// - Parameter path: 路径
    /// - Returns: 是否为Git仓库
    public static func isGitRepository(at path: String? = nil) -> Bool {
        do {
            _ = try Shell.runSync("git rev-parse --git-dir", at: path)
            return true
        } catch {
            return false
        }
    }

    /// 获取仓库根目录
    /// - Parameter path: 路径
    /// - Returns: 仓库根目录路径
    public static func repositoryRoot(at path: String? = nil) throws -> String {
        return try Shell.runSync("git rev-parse --show-toplevel", at: path)
    }

    /// 获取最新提交哈希
    /// - Parameters:
    ///   - short: 是否返回短哈希
    ///   - path: 仓库路径
    /// - Returns: 提交哈希
    public static func lastCommitHash(short: Bool = false, at path: String? = nil) throws -> String {
        let option = short ? "--short" : ""
        return try Shell.runSync("git rev-parse \(option) HEAD", at: path)
    }

    /// 获取用户名
    /// - Parameters:
    ///   - global: 是否全局配置
    ///   - path: 仓库路径
    /// - Returns: 用户名
    public static func userName(global: Bool = false, at path: String? = nil) throws -> String {
        let scope = global ? "--global" : ""
        return try Shell.runSync("git config \(scope) user.name", at: path)
    }

    /// 获取邮箱
    /// - Parameters:
    ///   - global: 是否全局配置
    ///   - path: 仓库路径
    /// - Returns: 邮箱
    public static func userEmail(global: Bool = false, at path: String? = nil) throws -> String {
        let scope = global ? "--global" : ""
        return try Shell.runSync("git config \(scope) user.email", at: path)
    }

    /// 获取用户配置
    /// - Parameters:
    ///   - global: 是否获取全局配置
    ///   - path: 仓库路径
    /// - Returns: 用户配置信息
    public static func getUserConfig(global: Bool = false, at path: String? = nil) throws -> (name: String, email: String) {
        let scope = global ? "--global" : ""
        let name = try Shell.runSync("git config \(scope) user.name", at: path)
        let email = try Shell.runSync("git config \(scope) user.email", at: path)
        return (name: name, email: email)
    }

    /// 配置用户信息
    /// - Parameters:
    ///   - name: 用户名
    ///   - email: 邮箱
    ///   - global: 是否全局配置
    ///   - path: 仓库路径
    /// - Returns: 执行结果
    public static func configUser(name: String, email: String, global: Bool = false, at path: String? = nil) throws -> String {
        let scope = global ? "--global" : ""
        let nameResult = try Shell.runSync("git config \(scope) user.name \(shellQuoted(name))", at: path)
        let emailResult = try Shell.runSync("git config \(scope) user.email \(shellQuoted(email))", at: path)
        return "Name: \(nameResult)\nEmail: \(emailResult)"
    }
}
#endif

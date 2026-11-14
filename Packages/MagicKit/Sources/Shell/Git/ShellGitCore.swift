import Foundation
import OSLog
import SwiftUI

#if os(macOS)
    /// Git命令执行类
    /// 提供常用的Git操作功能
    public class ShellGit: SuperLog {
        public static let emoji = "🔧"

        /// 初始化Git仓库
        /// - Parameter path: 仓库路径
        /// - Returns: 执行结果
        public static func initRepository(at path: String) throws -> String {
            return try Shell.runSync("git init", at: path)
        }
    }
#endif

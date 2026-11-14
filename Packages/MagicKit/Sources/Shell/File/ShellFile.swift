import Foundation
import OSLog
#if os(macOS)
/// 文件操作相关的Shell命令工具类
class ShellFile: SuperLog {
    static let emoji = "📁"

    static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    static func shellPathOperand(_ value: String) -> String {
        shellQuoted(value.hasPrefix("-") ? "./\(value)" : value)
    }

    static func isDirExistsCommand(_ dir: String) -> String {
        let quotedDir = shellQuoted(dir)
        return """
            if [ ! -d \(quotedDir) ]; then
                echo "false"
            else
                echo "true"
            fi
        """
    }

    static func isFileExistsCommand(_ path: String) -> String {
        let quotedPath = shellQuoted(path)
        return """
            if [ ! -f \(quotedPath) ]; then
                echo "false"
            else
                echo "true"
            fi
        """
    }

    static func makeDirCommand(_ dir: String) -> String {
        let quotedDir = shellQuoted(dir)
        return """
            if [ ! -d \(quotedDir) ]; then
                mkdir -p -- \(quotedDir)
            else
                echo \(quotedDir) 已经存在
            fi
        """
    }

    static func getFileContentCommand(_ path: String) -> String {
        "cat -- \(shellQuoted(path))"
    }

    static func removeCommand(_ path: String) -> String {
        "rm -rf -- \(shellQuoted(path))"
    }

    static func copyCommand(_ source: String, to destination: String) -> String {
        "cp -r -- \(shellQuoted(source)) \(shellQuoted(destination))"
    }

    static func moveCommand(_ source: String, to destination: String) -> String {
        "mv -- \(shellQuoted(source)) \(shellQuoted(destination))"
    }

    static func getFileSizeCommand(_ path: String) -> String {
        "stat -f%z -- \(shellQuoted(path))"
    }

    static func listFilesCommand(_ dir: String) -> String {
        "ls -1 -- \(shellQuoted(dir))"
    }

    static func getPermissionsCommand(_ path: String) -> String {
        "stat -f%Sp -- \(shellQuoted(path))"
    }

    static func changePermissionsCommand(_ path: String, permissions: String) -> String {
        "chmod \(shellQuoted(permissions)) \(shellPathOperand(path))"
    }
    
    /// 检查目录是否存在
    /// - Parameter dir: 目录路径
    /// - Returns: 目录是否存在
    func isDirExists(_ dir: String) -> Bool {
        do {
            let result = try Shell.runSync(Self.isDirExistsCommand(dir))
            return result.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        } catch {
            os_log("\(self.t)检查目录存在性失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 检查文件是否存在
    /// - Parameter path: 文件路径
    /// - Returns: 文件是否存在
    func isFileExists(_ path: String) -> Bool {
        do {
            let result = try Shell.runSync(Self.isFileExistsCommand(path))
            return result.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        } catch {
            os_log("\(self.t)检查文件存在性失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 创建目录
    /// - Parameters:
    ///   - dir: 目录路径
    ///   - verbose: 是否输出详细日志
    func makeDir(_ dir: String, verbose: Bool = false) {
        if verbose {
            os_log("\(self.t)MakeDir -> \(dir)")
        }
        
        do {
            _ = try Shell.runSync(Self.makeDirCommand(dir))
        } catch {
            os_log("\(self.t)创建目录失败: \(error.localizedDescription)")
        }
    }
    
    /// 创建文件并写入内容
    /// - Parameters:
    ///   - path: 文件路径
    ///   - content: 文件内容
    func makeFile(_ path: String, content: String) {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            os_log("\(self.t)创建文件失败: \(error.localizedDescription)")
        }
    }
    
    /// 获取文件内容
    /// - Parameter path: 文件路径
    /// - Returns: 文件内容
    /// - Throws: 读取失败时抛出错误
    func getFileContent(_ path: String) throws -> String {
        try Shell.runSync(Self.getFileContentCommand(path))
    }
    
    /// 删除文件或目录
    /// - Parameter path: 文件或目录路径
    /// - Throws: 删除失败时抛出错误
    func remove(_ path: String) throws {
        try Shell.runSync(Self.removeCommand(path))
    }
    
    /// 复制文件或目录
    /// - Parameters:
    ///   - source: 源路径
    ///   - destination: 目标路径
    /// - Throws: 复制失败时抛出错误
    func copy(_ source: String, to destination: String) throws {
        try Shell.runSync(Self.copyCommand(source, to: destination))
    }
    
    /// 移动文件或目录
    /// - Parameters:
    ///   - source: 源路径
    ///   - destination: 目标路径
    /// - Throws: 移动失败时抛出错误
    func move(_ source: String, to destination: String) throws {
        try Shell.runSync(Self.moveCommand(source, to: destination))
    }
    
    /// 获取文件大小
    /// - Parameter path: 文件路径
    /// - Returns: 文件大小（字节）
    /// - Throws: 获取失败时抛出错误
    func getFileSize(_ path: String) throws -> Int {
        let result = try Shell.runSync(Self.getFileSizeCommand(path))
        return Int(result.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }
    
    /// 获取目录下的文件列表
    /// - Parameter dir: 目录路径
    /// - Returns: 文件名数组
    /// - Throws: 获取失败时抛出错误
    func listFiles(_ dir: String) throws -> [String] {
        let result = try Shell.runSync(Self.listFilesCommand(dir))
        return result.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    /// 获取文件权限
    /// - Parameter path: 文件路径
    /// - Returns: 权限字符串
    /// - Throws: 获取失败时抛出错误
    func getPermissions(_ path: String) throws -> String {
        try Shell.runSync(Self.getPermissionsCommand(path))
    }
    
    /// 修改文件权限
    /// - Parameters:
    ///   - path: 文件路径
    ///   - permissions: 权限（如 "755"）
    /// - Throws: 修改失败时抛出错误
    func changePermissions(_ path: String, permissions: String) throws {
        try Shell.runSync(Self.changePermissionsCommand(path, permissions: permissions))
    }
}
#endif

// MARK: - Preview

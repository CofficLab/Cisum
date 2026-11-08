import Foundation
import OSLog
import SwiftUI

#if os(iOS) || os(visionOS)
    // iOS / visionOS 不支持本地 shell 执行，提供受限占位实现，避免在这些
    // 目标下编译失败
    @available(iOS 13.0, visionOS 2.0, *)
    class Shell: SuperLog {
        static let emoji = "🐚"

        static func run(_ command: String, at path: String? = nil, verbose: Bool = false) async throws -> String {
            throw ShellError.commandFailed("Shell is unavailable on this platform", command)
        }

        @discardableResult
        static func runSync(_ command: String, at path: String? = nil, verbose: Bool = false) throws -> String {
            throw ShellError.commandFailed("Shell is unavailable on this platform", command)
        }

        static func runMultiple(_ commands: [String], at path: String? = nil, verbose: Bool = false) throws -> [String] {
            throw ShellError.commandFailed("Shell is unavailable on this platform", commands.joined(separator: "; "))
        }

        static func runWithStatus(_ command: String, at path: String? = nil, verbose: Bool = false) -> (output: String, exitCode: Int32) {
            ("Shell is unavailable on this platform", -1)
        }

        static func isCommandAvailable(_ command: String) -> Bool { false }
        static func getCommandPath(_ command: String) -> String? { nil }
        static func configureGitCredentialCache() -> String { "Shell is unavailable on this platform" }
    }
#endif

#if os(macOS)

    /// Shell命令执行的核心类
    /// 提供基础的Shell命令执行功能
    public class Shell: SuperLog {
        public static let emoji = "🐚"

        static func shellQuoted(_ value: String) -> String {
            "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
        }

        static func commandLookupCommand(_ command: String) -> String? {
            let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return "which \(shellQuoted(trimmed))"
        }

        private static func execute(_ command: String, at path: String? = nil, verbose: Bool = false) throws -> String {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]

            if let path = path {
                process.currentDirectoryURL = URL(fileURLWithPath: path)
            }

            let outputPipe = Pipe()
            let errorURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            _ = FileManager.default.createFile(atPath: errorURL.path, contents: nil)
            let errorHandle = try FileHandle(forWritingTo: errorURL)
            defer {
                try? FileManager.default.removeItem(at: errorURL)
            }
            process.standardOutput = outputPipe
            process.standardError = errorHandle

            do {
                try process.run()
            } catch {
                throw ShellError.processStartFailed(error.localizedDescription)
            }

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            try? errorHandle.close()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = (try? String(contentsOf: errorURL, encoding: .utf8)) ?? ""
            let combinedOutput = errorOutput.isEmpty ? output : "\(output)\n\(errorOutput)"

            if verbose {
                os_log("\(self.t) \n➡️ Path: \n\(path ?? "Current Directory") (\(FileManager.default.currentDirectoryPath)) \n➡️ Command: \n\(command) \n➡️ Output: \n\(combinedOutput)")
            }

            if process.terminationStatus != 0 {
                os_log(.error, "\(self.t) ❌ Command failed \n ➡️ Path: \(path ?? "Current Directory") (\(FileManager.default.currentDirectoryPath)) \n ➡️ Command: \(command) \n ➡️ Output: \(combinedOutput) \n ➡️ Exit code: \(process.terminationStatus)")
                throw ShellError.commandFailed(combinedOutput, command)
            }

            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        /// 异步执行Shell命令
        /// - Parameters:
        ///   - command: 要执行的命令
        ///   - path: 执行命令的工作目录（可选）
        ///   - verbose: 是否输出详细日志
        /// - Returns: 命令执行结果
        /// - Throws: 执行失败时抛出错误
        public static func run(_ command: String, at path: String? = nil, verbose: Bool = false) async throws -> String {
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        continuation.resume(returning: try execute(command, at: path, verbose: verbose))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        /// 同步执行Shell命令（向后兼容，内部调用异步版本）
        /// - Parameters:
        ///   - command: 要执行的命令
        ///   - path: 执行命令的工作目录（可选）
        ///   - verbose: 是否输出详细日志
        /// - Returns: 命令执行结果
        /// - Throws: 执行失败时抛出错误
        @discardableResult
        public static func runSync(_ command: String, at path: String? = nil, verbose: Bool = false) throws -> String {
            try execute(command, at: path, verbose: verbose)
        }

        /// 执行多个命令
        /// - Parameters:
        ///   - commands: 命令数组
        ///   - path: 执行命令的工作目录（可选）
        ///   - verbose: 是否输出详细日志
        /// - Returns: 所有命令的执行结果数组
        /// - Throws: 任何命令执行失败时抛出错误
        public static func runMultiple(_ commands: [String], at path: String? = nil, verbose: Bool = false) throws -> [String] {
            var results: [String] = []

            for command in commands {
                let result = try runSync(command, at: path, verbose: verbose)
                results.append(result)
            }

            return results
        }

        /// 执行命令并返回退出状态码
        /// - Parameters:
        ///   - command: 要执行的命令
        ///   - path: 执行命令的工作目录（可选）
        ///   - verbose: 是否输出详细日志
        /// - Returns: 元组包含输出和退出状态码
        public static func runWithStatus(_ command: String, at path: String? = nil, verbose: Bool = false) -> (output: String, exitCode: Int32) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]

            if let path = path {
                process.currentDirectoryURL = URL(fileURLWithPath: path)
            }

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let outputHandle = pipe.fileHandleForReading

            // 使用 @unchecked Sendable 包装器避免闭包中的数据竞争警告
            final class OutputCollector: @unchecked Sendable {
                var data = Data()
                var isReadingComplete = false
            }
            let collector = OutputCollector()

            // 使用信号量来确保数据读取完成
            let semaphore = DispatchSemaphore(value: 0)

            outputHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    // 数据读取完成
                    collector.isReadingComplete = true
                    semaphore.signal()
                } else {
                    collector.data.append(data)
                }
            }

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                return ("Execution failed: \(error.localizedDescription)", -1)
            }

            // 等待数据读取完成，最多等待1秒
            let result = semaphore.wait(timeout: .now() + 1.0)

            // 清理 handler
            outputHandle.readabilityHandler = nil

            // 如果超时，尝试读取剩余数据
            if result == .timedOut || !collector.isReadingComplete {
                let remainingData = outputHandle.readDataToEndOfFile()
                if !remainingData.isEmpty {
                    collector.data.append(remainingData)
                }
            }

            guard let output = String(data: collector.data, encoding: .utf8) else {
                return ("String conversion failed: could not convert output data to UTF-8 string, data size: \(collector.data.count) bytes", -2)
            }

            if verbose {
                os_log("\(self.t)\(command)")
                os_log("\(output)")
                os_log("\(self.t)Exit code: \(process.terminationStatus)")
            }

            return (output.trimmingCharacters(in: .whitespacesAndNewlines), process.terminationStatus)
        }

        /// 检查命令是否可用
        /// - Parameter command: 命令名
        /// - Returns: 命令是否可用
        public static func isCommandAvailable(_ command: String) -> Bool {
            do {
                guard let lookupCommand = commandLookupCommand(command) else { return false }
                _ = try runSync(lookupCommand)
                return true
            } catch {
                return false
            }
        }

        /// 获取命令的完整路径
        /// - Parameter command: 命令名
        /// - Returns: 命令的完整路径
        public static func getCommandPath(_ command: String) -> String? {
            do {
                guard let lookupCommand = commandLookupCommand(command) else { return nil }
                let path = try runSync(lookupCommand)
                return path.isEmpty ? nil : path
            } catch {
                return nil
            }
        }

        /// 配置Git凭证缓存
        /// - Returns: 配置结果
        public static func configureGitCredentialCache() -> String {
            do {
                return try self.runSync("git config --global credential.helper cache")
            } catch {
                return error.localizedDescription
            }
        }
    }

#endif

// MARK: - Preview

#if DEBUG && os(macOS)
    #Preview("Shell Demo") {
        Text("Shell Demo")
            .padding()
    }
#endif

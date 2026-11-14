import Combine
import OSLog
import SwiftUI

/// Collects app logs and mirrors them to the system logger.
public class MagicLogger: ObservableObject, @unchecked Sendable {
    public static let shared = MagicLogger()

    @Published public private(set) var logs: [MagicLogEntry] = []
    @Published public var app: String

    private let maxLogCount = 1000
    private let lock = NSLock()

    public init(app: String = "Default") {
        self.app = app
    }

    public static func log(_ message: String, level: MagicLogEntry.Level, caller: String = #fileID, line: Int = #line) {
        shared.log(message, level: level, caller: fileName(from: caller), line: line)
    }

    public static func info(_ message: String, caller: String = #fileID, line: Int = #line) {
        shared.info(message, caller: fileName(from: caller), line: line)
    }

    public static func warning(_ message: String, caller: String = #fileID, line: Int = #line) {
        shared.warning(message, caller: fileName(from: caller), line: line)
    }

    public static func error(_ message: String, caller: String = #fileID, line: Int = #line) {
        shared.error(message, caller: fileName(from: caller), line: line)
    }

    public static func debug(_ message: String, caller: String = #fileID, line: Int = #line) {
        shared.debug(message, caller: fileName(from: caller), line: line)
    }

    public static func clearLogs() {
        shared.clearLogs()
    }

    public func log(_ message: String, level: MagicLogEntry.Level, caller: String = #fileID, line: Int = #line) {
        addLog(.init(message: message, level: level, caller: Self.fileName(from: caller), line: line))
    }

    public func info(_ message: String, caller: String = #fileID, line: Int = #line) {
        addLog(.init(message: message, level: .info, caller: Self.fileName(from: caller), line: line))
    }

    public func warning(_ message: String, caller: String = #fileID, line: Int = #line) {
        addLog(.init(message: message, level: .warning, caller: Self.fileName(from: caller), line: line))
    }

    public func error(_ message: String, caller: String = #fileID, line: Int = #line) {
        addLog(.init(message: message, level: .error, caller: Self.fileName(from: caller), line: line))
    }

    public func debug(_ message: String, caller: String = #fileID, line: Int = #line) {
        addLog(.init(message: message, level: .debug, caller: Self.fileName(from: caller), line: line))
    }

    public func clearLogs() {
        if Thread.isMainThread {
            logs.removeAll()
        } else {
            DispatchQueue.main.async {
                self.logs.removeAll()
            }
        }
    }

    private static func fileName(from file: String) -> String {
        file.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? file
    }

    private func addLog(_ entry: MagicLogEntry) {
        lock.lock()
        defer { lock.unlock() }

        DispatchQueue.main.async {
            self.logs.append(entry)
            if self.logs.count > self.maxLogCount {
                self.logs.removeFirst(self.logs.count - self.maxLogCount)
            }
        }

        let logType: OSLogType = switch entry.level {
        case .info, .warning:
            .info
        case .error:
            .error
        case .debug:
            .debug
        }

        var title = "\(entry.caller.withContextEmoji):\(entry.line ?? 0)"
        title = title.padding(toLength: 30, withPad: " ", startingAt: 0)
        os_log(logType, "\(Thread.currentQosDescription) | \(title) | \(entry.originalMessage.withContextEmoji)")
    }
}

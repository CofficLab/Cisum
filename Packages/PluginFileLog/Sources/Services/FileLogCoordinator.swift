import Foundation
import OSLog

/// 磁盘日志协调器
///
/// 通过 OSLogStore 订阅 subsystem == "com.yueyi.cisum" 的日志条目，
/// 异步写入磁盘文件。支持自动轮转和过期清理。
///
/// ## 设计
///
/// ```text
/// 现有代码（零改动）
///   os_log("\(self.t)...")
///   SomePlugin.logger.error("...")
///         │
///         ▼
/// os.Logger → 系统统一日志（Console.app / log stream 可查）
///         │
///         ▼
/// FileLogCoordinator（OSLogStore 轮询）
///         │
///         ▼
/// ~/Library/Application Support/com.yueyi.cisum/db_debug_v1/
///   com.coffic.cisum.plugin.file-log/
///   ├── 2026-05-26_10-36-00.log
///   ├── 2026-05-26_11-02-33.log
///   └── ...
/// ```
///
/// ## 自动管理规则
///
/// | 规则 | 值 |
/// |------|-----|
/// | 单文件大小上限 | 5 MB |
/// | 过期清理 | 7 天 |
/// | 轮转触发 | 启动时新建 + 超大小自动轮转 |
/// | 轮询间隔 | 2 秒 |
public final class FileLogCoordinator: @unchecked Sendable {
    public static let shared = FileLogCoordinator()

    // MARK: - Constants

    private let subsystem = "com.yueyi.cisum"
    private let maxFileSize: Int = 5 * 1024 * 1024  // 5 MB
    private let maxRetentionDays: Int = 7
    private let pollInterval: TimeInterval = 2.0

    // MARK: - State

    private let queue = DispatchQueue(label: "com.yueyi.cisum.file-log", qos: .utility)
    private var currentFileHandle: FileHandle?
    private var currentFilePath: URL?
    private var isRunning = false
    private var isFileLoggingDisabled = false
    private var lastPolledDate = Date.distantPast
    private var pollTimer: DispatchSourceTimer?

    // MARK: - Configuration

    public nonisolated(unsafe) var configuration: FileLogConfiguration = DefaultFileLogConfiguration()

    // MARK: - Log Directory

    private var logsDirectory: URL {
        configuration.logsDirectory()
    }

    // MARK: - Public Lifecycle

    private init() {}

    /// 启动磁盘日志收集
    public func start() {
        queue.async { [self] in
            guard !isRunning else { return }
            isRunning = true
            isFileLoggingDisabled = false
            try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
            purgeExpiredLogs()
            rotateLogFile()
            schedulePollTimer()
        }
    }

    /// 停止磁盘日志收集并 flush 剩余条目
    public func stop() {
        queue.async { [self] in
            guard isRunning else { return }
            isRunning = false
            pollTimer?.cancel()
            pollTimer = nil
            pollOnce() // flush 剩余
            closeCurrentFile()
        }
    }

    // MARK: - Log Rotation

    private func rotateLogFile() {
        closeCurrentFile()
        guard !isFileLoggingDisabled else { return }

        let filePath = FileLogRotation.uniqueLogFileURL(
            baseName: logDateFormatter.string(from: Date()),
            in: logsDirectory
        )

        guard FileManager.default.createFile(atPath: filePath.path, contents: nil) else {
            handleFileWriteFailure(CocoaError(.fileWriteUnknown))
            return
        }

        do {
            currentFileHandle = try FileHandle(forWritingTo: filePath)
        } catch {
            handleFileWriteFailure(error)
            return
        }
        currentFilePath = filePath

        // 写入 header
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

        #if DEBUG
        let environment = "Debug"
        #else
        let environment = "Production"
        #endif

        let header = """
        === Cisum Log ===
        Version: \(version) (\(build))
        Environment: \(environment)
        Date: \(Date())
        ===

        """
        writeData(Data(header.utf8))
    }

    private func closeCurrentFile() {
        guard let handle = currentFileHandle else { return }
        currentFileHandle = nil
        currentFilePath = nil
        var closeError: Error?
        do {
            try handle.synchronize()
        } catch {
            closeError = error
        }

        do {
            try handle.close()
        } catch {
            closeError = closeError ?? error
        }

        if let closeError {
            handleFileWriteFailure(closeError)
        }
    }

    // MARK: - Polling

    private func schedulePollTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in
            self?.pollOnce()
        }
        timer.resume()
        pollTimer = timer
    }

    private func pollOnce() {
        guard isRunning, !isFileLoggingDisabled else { return }

        let store: OSLogStore
        do {
            store = try OSLogStore(scope: .currentProcessIdentifier)
        } catch {
            return
        }

        // 从上次轮询时间点之后获取新条目
        let position = store.position(date: lastPolledDate)
        lastPolledDate = Date()

        guard let entries = try? store.getEntries(
            at: position,
            matching: NSPredicate(format: "subsystem == %@", subsystem)
        ) else { return }

        var hasNewEntries = false
        for entry in entries {
            writeEntry(entry)
            hasNewEntries = true
        }

        if hasNewEntries {
            flushCurrentFile()
            if !isFileLoggingDisabled {
                checkFileSize()
            }
        }
    }

    // MARK: - Write

    private func writeEntry(_ entry: OSLogEntry) {
        let line: String
        if let logEntry = entry as? OSLogEntryLog {
            let level = logEntry.level.stringValue
            let time = entryTimeFormatter.string(from: entry.date)
            line = "[\(time)] [\(level)] [\(logEntry.category)] \(entry.composedMessage)\n"
        } else {
            let time = entryTimeFormatter.string(from: entry.date)
            line = "[\(time)] \(entry.composedMessage)\n"
        }
        writeData(Data(line.utf8))
    }

    private func writeData(_ data: Data) {
        guard let handle = currentFileHandle, !isFileLoggingDisabled else { return }
        do {
            try handle.write(contentsOf: data)
        } catch {
            handleFileWriteFailure(error)
        }
    }

    private func flushCurrentFile() {
        guard let handle = currentFileHandle, !isFileLoggingDisabled else { return }
        do {
            try handle.synchronize()
        } catch {
            handleFileWriteFailure(error)
        }
    }

    private func handleFileWriteFailure(_: Error) {
        guard !isFileLoggingDisabled else { return }
        isFileLoggingDisabled = true
        isRunning = false
        pollTimer?.cancel()
        pollTimer = nil

        let handle = currentFileHandle
        currentFileHandle = nil
        currentFilePath = nil
        try? handle?.close()
    }

    private func checkFileSize() {
        guard let path = currentFilePath,
              let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
              let size = FileLogFileSizePolicy.fileSize(from: attrs),
              size > maxFileSize else { return }
        rotateLogFile()
    }

    // MARK: - Cleanup

    private func purgeExpiredLogs() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        guard let cutoff = Calendar.current.date(
            byAdding: .day, value: -maxRetentionDays, to: Date()
        ) else { return }

        for file in files {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
                  let creationDate = attrs[.creationDate] as? Date,
                  creationDate < cutoff else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Formatters

    private lazy var logDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f
    }()

    private lazy var entryTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}

enum FileLogFileSizePolicy {
    static func fileSize(from attributes: [FileAttributeKey: Any]) -> Int? {
        if let number = attributes[.size] as? NSNumber {
            return normalizedSize(number.int64Value)
        }

        if let size = attributes[.size] as? Int {
            return normalizedSize(Int64(size))
        }

        if let size = attributes[.size] as? Int64 {
            return normalizedSize(size)
        }

        return nil
    }

    private static func normalizedSize(_ size: Int64) -> Int {
        guard size > 0 else { return 0 }
        return Int(min(size, Int64(Int.max)))
    }
}

enum FileLogRotation {
    static func uniqueLogFileURL(
        baseName: String,
        in directory: URL,
        fileExists: (URL) -> Bool = { FileLogRotation.pathExistsIncludingSymlink($0) }
    ) -> URL {
        let normalizedBaseName = baseName.isEmpty ? "Cisum Log" : baseName
        var candidate = directory
            .appendingPathComponent(normalizedBaseName)
            .appendingPathExtension("log")
        var suffix = 2

        while fileExists(candidate) {
            candidate = directory
                .appendingPathComponent("\(normalizedBaseName) \(suffix)")
                .appendingPathExtension("log")
            suffix += 1
        }

        return candidate
    }

    private static func pathExistsIncludingSymlink(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
            || (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
    }
}

// MARK: - OSLogEntryLog.Level String Representation

extension OSLogEntryLog.Level {
    var stringValue: String {
        switch self {
        case .undefined:    return "VERBOSE"
        case .debug:        return "DEBUG"
        case .info:         return "INFO"
        case .notice:       return "NOTICE"
        case .error:        return "ERROR"
        case .fault:        return "FAULT"
        @unknown default:   return "UNKNOWN"
        }
    }
}

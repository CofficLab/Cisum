import Combine
import Darwin
import Foundation
import OSLog

/// 目录监控器启动失败的错误类型。
public enum BookDirectoryMonitorError: Error, LocalizedError {
    case directoryUnavailable
    case fileDescriptorFailed
    
    public var errorDescription: String? {
        switch self {
        case .directoryUnavailable:
            return "Directory is unavailable or could not be created"
        case .fileDescriptorFailed:
            return "Failed to open file descriptor for directory monitoring"
        }
    }
}

/// 监听本地文件夹内容变化的专用类
/// - Note: macOS 使用 FSEvents 和 DispatchSource，iOS 使用轮询机制
public final class LocalDirectoryMonitor: SuperLog {
    public static let emoji = "💼"

    // MARK: - Types

    public typealias onChangeCallback = @Sendable (_ files: [URL], _ isInitialFetch: Bool, _ error: Error?) async -> Void

    /// 监听器状态管理（使用 Actor 确保线程安全）
    private actor MonitorState {
        private var isFirstFetch = true
        private var lastFileList: [URL] = []
        private var lastScanTime: Date?

        func getAndUpdateFirstFetch() -> Bool {
            let current = isFirstFetch
            isFirstFetch = false
            return current
        }

        func getFileList() -> [URL] {
            lastFileList
        }

        func updateFileList(_ list: [URL]) {
            lastFileList = list
        }

        func getLastScanTime() -> Date? {
            lastScanTime
        }

        func updateScanTime() {
            lastScanTime = Date()
        }

        func shouldNotifyChange(currentFiles: [URL], pollingInterval: TimeInterval) -> Bool {
            guard let lastTime = lastScanTime else {
                return true
            }
            let timeSinceLastScan = Date().timeIntervalSince(lastTime)
            return timeSinceLastScan >= pollingInterval
        }
    }

    // MARK: - Properties

    private let directoryURL: URL
    private let verbose: Bool
    private let caller: String
    private let onChange: onChangeCallback

    private var fileDescriptor: Int32 = -1
    private var monitor: DispatchSourceFileSystemObject?
    private var scanTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    private let state = MonitorState()

    // iOS 轮询配置
    private let isIOS: Bool
    private let pollingInterval: TimeInterval = 2.0 // iOS 上每 2 秒检查一次

    // MARK: - Initialization

    /// 初始化本地目录监听器
    /// - Parameters:
    ///   - directoryURL: 要监听的目录 URL
    ///   - verbose: 是否打印详细日志
    ///   - caller: 调用者名称
    ///   - onChange: 变化回调
    public init(
        directoryURL: URL,
        verbose: Bool,
        caller: String,
        onChange: @escaping onChangeCallback
    ) {
        self.directoryURL = directoryURL
        self.verbose = verbose
        self.caller = caller
        self.onChange = onChange
        // 检测是否为 iOS 平台
        #if os(iOS)
        self.isIOS = true
        #else
        self.isIOS = false
        #endif
    }

    // MARK: - Public Methods

    /// 启动监听
    /// - Returns: 取消令牌
    @discardableResult
    public func start() -> AnyCancellable {
        if isIOS {
            // iOS 使用轮询机制
            if verbose {
                os_log("\(self.t)📱 (\(self.caller)) iOS 平台：使用轮询机制监控目录")
                os_log("\(self.t)  • 轮询间隔：\(self.pollingInterval) 秒")
            }
            startPolling()
        } else {
            // macOS 使用 DispatchSource
            guard ensureDirectoryExists() else {
                // 启动失败时通知调用者，避免 waitForInitialSync 永远等待
                let onChange = self.onChange
                Task {
                    await onChange([], true, BookDirectoryMonitorError.directoryUnavailable)
                }
                return AnyCancellable {}
            }
            guard setupFileDescriptor() else {
                // 启动失败时通知调用者，避免 waitForInitialSync 永远等待
                let onChange = self.onChange
                Task {
                    await onChange([], true, BookDirectoryMonitorError.fileDescriptorFailed)
                }
                return AnyCancellable {}
            }
            setupMonitor()
            performInitialScan()
        }

        return AnyCancellable { [self] in
            self.cancel()
        }
    }

    // MARK: - Private Methods

    private func ensureDirectoryExists() -> Bool {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return true
            }

            os_log(.error, "\(self.t)❌ (\(self.caller)) 监控路径不是目录：\(self.directoryURL.path)")
            return false
        }

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            if verbose {
                os_log("\(self.t)✅ (\(self.caller)) 已创建监控目录：\(self.directoryURL.path)")
            }
            return true
        } catch {
            os_log(.error, "\(self.t)❌ (\(self.caller)) 创建监控目录失败：\(error.localizedDescription)")
            return false
        }
    }

    private func setupFileDescriptor() -> Bool {
        fileDescriptor = Darwin.open(self.directoryURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            os_log(.error, "\(self.t)❌ (\(self.caller)) 打开文件描述符失败")
            return false
        }

        if verbose {
            os_log("\(self.t)🎯 (\(self.caller)) 已打开文件描述符")
            os_log("\(self.t)  • 目录：\(self.directoryURL.lastPathComponent)")
        }

        return true
    }

    private func setupMonitor() {
        monitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: .global(qos: .background)
        )

        monitor?.setEventHandler { [weak self] in
            guard let self = self else { return }
            // 使用 MainActor.run 确保在主线程上处理事件
            Task.detached { [weak self] in
                guard let self = self else { return }
                do {
                    try await self.scanDirectory()
                } catch {
                    let onChange = self.onChange
                    await onChange([], false, error)
                }
            }
        }

        monitor?.resume()

        if verbose {
            os_log("\(self.t)👀 (\(self.caller)) 正在监控目录")
            os_log("\(self.t)  • 目录：\(self.directoryURL.lastPathComponent)")
        }
    }

    private func performInitialScan() {
        let onChange = self.onChange
        scanTask = Task {
            do {
                try await scanDirectory()
            } catch {
                await onChange([], false, error)
            }
        }
    }

    private func handleFileSystemEvent() async {
        do {
            try await scanDirectory()
        } catch {
            await onChange([], false, error)
        }
    }

    private func scanDirectory() async throws {
        if verbose {
            os_log("\(self.t)🔍 (\(self.caller)) 扫描目录")
            os_log("\(self.t)  • 路径：\(self.directoryURL.path)")
        }

        let fileManager = FileManager.default

        // 如果目录不存在，尝试创建
        if !fileManager.fileExists(atPath: self.directoryURL.path) {
            if verbose {
                os_log("\(self.t)📁 (\(self.caller)) 目录不存在，尝试创建")
            }

            do {
                try fileManager.createDirectory(at: self.directoryURL, withIntermediateDirectories: true, attributes: nil)
                if verbose {
                    os_log("\(self.t)✅ (\(self.caller)) 目录创建成功")
                }
            } catch {
                os_log(.error, "\(self.t)❌ (\(self.caller)) 目录创建失败：\(error.localizedDescription)")
                throw URLError(.fileDoesNotExist)
            }
        }

        let urls = try fileManager.contentsOfDirectory(
            at: self.directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        if verbose {
            os_log("\(self.t)📝 (\(self.caller)) 扫描完成")
            os_log("\(self.t)  • 文件数量：\(urls.count)")

            // 打印文件列表
            for i in 0..<min(urls.count, 10) {
                os_log("\(self.t)  • [\(i)] \(urls[i].lastPathComponent)")
            }

            if urls.count > 10 {
                os_log("\(self.t)  • ... 还有 \(urls.count - 10) 个文件")
            }
        }

        let sortedUrls = Self.sortedFileList(urls)
        await state.updateFileList(sortedUrls)
        await state.updateScanTime()

        let isFirstFetch = await state.getAndUpdateFirstFetch()
        await onChange(sortedUrls, isFirstFetch, nil)
    }

    private func cancel() {
        if verbose {
            os_log("\(self.t)⏹️ (\(self.caller)) 停止本地监控器")
        }

        scanTask?.cancel()
        monitor?.cancel()
        pollingTask?.cancel()

        if fileDescriptor >= 0 {
            Darwin.close(fileDescriptor)
        }
    }

    // MARK: - iOS Polling

    private func startPolling() {
        if verbose {
            os_log("\(self.t)🚀 (\(self.caller)) 创建轮询任务")
        }

        pollingTask = Task { [weak self] in
            guard let self = self else {
                return
            }

            if self.verbose {
                os_log("\(self.t)✅ (\(self.caller)) 轮询任务已启动")
            }

            // 首次扫描
            if self.verbose {
                os_log("\(self.t)🎬 (\(self.caller)) 开始首次扫描")
            }

            do {
                try await self.scanDirectory()

                if self.verbose {
                    os_log("\(self.t)✅ (\(self.caller)) 首次扫描完成，开始定期轮询")
                    os_log("\(self.t)  • 轮询间隔：\(self.pollingInterval) 秒")
                }
            } catch {
                if self.verbose {
                    os_log(.error, "\(self.t)❌ (\(self.caller)) 首次扫描失败：\(error.localizedDescription)")
                }
                await self.onChange([], false, error)
                return
            }

            // 定期轮询
            if self.verbose {
                os_log("\(self.t)🔄 (\(self.caller)) 进入轮询循环")
            }

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(self.pollingInterval * 1_000_000_000))

                    let previousFiles = await self.state.getFileList()
                    let currentFiles = try await self.scanDirectoryForPolling()

                    // 只有当文件真正变化时才通知
                    if Self.hasFileListChanged(previous: previousFiles, current: currentFiles) {
                        if self.verbose {
                            os_log("\(self.t)🔄 (\(self.caller)) 检测到文件变化")
                            os_log("\(self.t)  • 之前文件数：\(previousFiles.count)")
                            os_log("\(self.t)  • 当前文件数：\(currentFiles.count)")
                        }
                        await self.state.updateFileList(currentFiles)
                        await self.state.updateScanTime()
                        // 通知变化
                        await self.onChange(currentFiles, false, nil)
                    } else {
                        await self.state.updateScanTime()
                    }
                } catch is CancellationError {
                    // 任务被取消，正常退出，不记录错误
                    break
                } catch {
                    if self.verbose {
                        os_log(.error, "\(self.t)❌ (\(self.caller)) 轮询扫描失败：\(error.localizedDescription)")
                    }
                }
            }

            if self.verbose {
                os_log("\(self.t)⏹️ (\(self.caller)) 轮询任务已取消")
            }
        }

        if verbose {
            os_log("\(self.t)✅ (\(self.caller)) 轮询任务创建完成")
        }
    }

    private func scanDirectoryForPolling() async throws -> [URL] {
        let fileManager = FileManager.default

        // 如果目录不存在，尝试创建
        if !fileManager.fileExists(atPath: self.directoryURL.path) {
            do {
                try fileManager.createDirectory(at: self.directoryURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw URLError(.fileDoesNotExist)
            }
        }

        let urls = try fileManager.contentsOfDirectory(
            at: self.directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        // 只返回文件列表，不调用 onChange（由调用者决定是否通知）
        return Self.sortedFileList(urls)
    }

    static func hasFileListChanged(previous: [URL], current: [URL]) -> Bool {
        previous != current
    }

    private static func sortedFileList(_ urls: [URL]) -> [URL] {
        urls.sorted { lhs, rhs in
            lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
    }
}

@preconcurrency import Combine
import Foundation
import CisumUIComponents
import MagicKit
import OSLog

/// 音频库文件系统同步器。
///
/// 只负责把目录监控事件转换成同步/删除回调；回调的具体数据实现由
/// `AudioDBDataPlugin` 注入，因此这个类型不会穿透 Provider 边界。
final class AudioFileSystemMonitor: SuperLog, @unchecked Sendable {
    typealias DiskProvider = @Sendable () async -> URL?
    typealias SyncItems = @Sendable (_ items: [URL], _ isFirst: Bool) async -> Void
    typealias DeleteItems = @Sendable (_ urls: [URL]) async throws -> Void

    static let verbose = false

    private let diskProvider: DiskProvider
    private let syncItems: SyncItems
    private let deleteItems: DeleteItems

    private var monitor: Cancellable?
    private let state = State()
    private let runIDLock = NSLock()
    private var activeRunIDSnapshot: UUID?

    init(
        diskProvider: @escaping DiskProvider,
        syncItems: @escaping SyncItems,
        deleteItems: @escaping DeleteItems
    ) {
        self.diskProvider = diskProvider
        self.syncItems = syncItems
        self.deleteItems = deleteItems
    }

    static func shouldPerformFullSync(isFirst: Bool, disk: URL?) -> Bool {
        isFirst || !(disk?.checkIsICloud(verbose: false) ?? true)
    }

    static func shouldContinueRunning(runID: UUID, activeRunID: UUID?, isRunning: Bool) -> Bool {
        isRunning && activeRunID == runID
    }

    static func shouldProcessMonitorEvent(runID: UUID, activeRunID: UUID?, isRunning: Bool) -> Bool {
        shouldContinueRunning(runID: runID, activeRunID: activeRunID, isRunning: isRunning)
    }

    static func shouldSyncMonitorItems(error: Error?) -> Bool {
        error == nil
    }

    static func shouldApplyCancellation(cancelledRunID: UUID?, activeRunID: UUID?) -> Bool {
        guard let cancelledRunID else { return true }
        return cancelledRunID == activeRunID
    }

    func execute() async throws {
        guard let disk = await diskProvider() else {
            if Self.verbose {
                os_log("❌ Unable to resolve audio disk path")
            }
            return
        }

        if Self.verbose {
            os_log("👀 Start monitoring audio disk: \(disk.path)")
        }

        let runID = UUID()
        setActiveRunIDSnapshot(runID)
        await state.start(runID)

        await withCheckedContinuation { continuation in
            monitor = disk.onDirChange(
                verbose: Self.verbose,
                caller: String(describing: Self.self) + ".execute",
                onChange: { @Sendable [weak self] items, isFirst, error in
                    guard let self else { return }

                    Task {
                        guard await self.state.shouldProcessMonitorEvent(runID) else {
                            return
                        }

                        guard Self.shouldSyncMonitorItems(error: error) else {
                            if let error {
                                os_log(.error, "❌ Audio file system scan failed: \(error.localizedDescription)")
                            }
                            return
                        }

                        if Self.verbose {
                            os_log("📂 Audio file system changed: \(items.count) item(s), first: \(isFirst)")
                        }

                        await self.syncItems(items, isFirst)
                    }
                },
                onDeleted: { @Sendable [weak self] urls in
                    guard let self else { return }

                    Task {
                        guard await self.state.shouldProcessMonitorEvent(runID) else {
                            return
                        }

                        if Self.verbose {
                            os_log("🗑️ Audio files deleted: \(urls.count)")
                        }

                        do {
                            try await self.deleteItems(urls)
                        } catch {
                            os_log(.error, "❌ Audio deletion sync failed: \(error.localizedDescription)")
                            return
                        }

                        if Self.verbose {
                            os_log("✅ Audio deletion sync completed")
                        }
                    }
                },
                onProgress: { _, _ in }
            )

            continuation.resume()
        }

        while await state.shouldContinue(runID) {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        if Self.verbose {
            os_log("✅ Audio file system monitor finished")
        }

        clearActiveRunIDSnapshot(runID)
    }

    func cancel() {
        let runID = currentRunIDSnapshot()
        Task { @Sendable [weak self] in
            guard let self else { return }
            await self.state.cancel(runID: runID)
        }

        monitor?.cancel()
        monitor = nil

        if Self.verbose {
            os_log("⏹️ Audio file system monitor stopped")
        }
    }

    private func setActiveRunIDSnapshot(_ runID: UUID) {
        runIDLock.lock()
        activeRunIDSnapshot = runID
        runIDLock.unlock()
    }

    private func clearActiveRunIDSnapshot(_ runID: UUID) {
        runIDLock.lock()
        if activeRunIDSnapshot == runID {
            activeRunIDSnapshot = nil
        }
        runIDLock.unlock()
    }

    private func currentRunIDSnapshot() -> UUID? {
        runIDLock.lock()
        defer { runIDLock.unlock() }
        return activeRunIDSnapshot
    }

    private actor State {
        var isRunning = false
        var activeRunID: UUID?

        func start(_ runID: UUID) {
            activeRunID = runID
            isRunning = true
        }

        func cancel(runID: UUID?) {
            guard AudioFileSystemMonitor.shouldApplyCancellation(
                cancelledRunID: runID,
                activeRunID: activeRunID
            ) else {
                return
            }

            activeRunID = nil
            isRunning = false
        }

        func shouldContinue(_ runID: UUID) -> Bool {
            AudioFileSystemMonitor.shouldContinueRunning(
                runID: runID,
                activeRunID: activeRunID,
                isRunning: isRunning
            )
        }

        func shouldProcessMonitorEvent(_ runID: UUID) -> Bool {
            AudioFileSystemMonitor.shouldProcessMonitorEvent(
                runID: runID,
                activeRunID: activeRunID,
                isRunning: isRunning
            )
        }
    }
}

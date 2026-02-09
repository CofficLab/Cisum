@preconcurrency import Combine
import Foundation
import MagicKit
import SwiftUI
import OSLog

/// 文件系统监控任务
///
/// 监听音频文件系统变化，调用 AudioRepo 操作数据库。
/// 负责将文件系统变化同步到数据库。
final class FileSystemMonitorJob: AudioJob, SuperLog, @unchecked Sendable {
    static let verbose = false

    nonisolated let identifier = "com.cisum.audio.job.filesystem-monitor"
    nonisolated let name = "文件系统监控"
    nonisolated let description = "监听音频文件系统变化，同步到数据库"

    private var monitor: Cancellable?
    private let state = State()

    // 防抖间隔（秒）
    private let debounceInterval: TimeInterval = 2.0

    /// 内部状态管理 actor
    private actor State {
        var isRunning: Bool = false
        var lastSyncTime: Date?

        func setRunning(_ running: Bool) {
            isRunning = running
        }

        func getRunning() -> Bool {
            isRunning
        }

        func shouldSync() -> Bool {
            guard let lastTime = lastSyncTime else {
                lastSyncTime = Date()
                return true
            }

            let now = Date()
            let elapsed = now.timeIntervalSince(lastTime)

            if elapsed < 2.0 {
                return false
            }

            lastSyncTime = Date()
            return true
        }
    }

    func execute() async throws {
        guard let disk = await AudioPlugin.getAudioDisk() else {
            if Self.verbose {
                os_log("\(self.t)❌ 无法获取音频磁盘路径")
            }
            return
        }

        if Self.verbose {
            os_log("\(self.t)👀 开始监控: \(disk.shortPath())")
        }

        await state.setRunning(true)

        // 创建监控器
        await withCheckedContinuation { continuation in
            monitor = disk.onDirChange(
                verbose: Self.verbose,
                caller: self.className + ".execute",
                onChange: { @Sendable [weak self] items, isFirst, _ in
                    guard let self = self else { return }

                    Task {
                        // 防抖处理
                        guard await self.state.shouldSync() else {
                            return
                        }

                        if Self.verbose {
                            os_log("\(self.t)📂 检测到文件系统变化")
                            os_log("\(self.t)  • 文件数量: \(items.count)")
                            os_log("\(self.t)  • 是否首次: \(isFirst)")
                        }

                        // 调用 AudioRepo 同步数据
                        guard let repo = await AudioPlugin.getAudioRepo() else {
                            if Self.verbose {
                                os_log("\(self.t)❌ 无法获取 AudioRepo 实例")
                            }
                            return
                        }

                        await repo.sync(items, verbose: Self.verbose, isFirst: isFirst)
                    }
                },
                onDeleted: { @Sendable [weak self] urls in
                    guard let self = self else { return }

                    Task {
                        if Self.verbose {
                            os_log("\(self.t)🗑️ 检测到文件删除")
                            os_log("\(self.t)  • 删除数量: \(urls.count)")

                            // 列出被删除的文件
                            let previewCount = min(5, urls.count)
                            if previewCount > 0 {
                                os_log("\(self.t)  • 删除文件预览:")
                                for i in 0 ..< previewCount {
                                    os_log("\(self.t)    \(i + 1). \(urls[i].lastPathComponent)")
                                }
                                if urls.count > previewCount {
                                    os_log("\(self.t)    ... 还有 \(urls.count - previewCount) 个文件")
                                }
                            }
                        }

                        // 调用 AudioRepo 删除数据
                        guard let repo = await AudioPlugin.getAudioRepo() else {
                            if Self.verbose {
                                os_log("\(self.t)❌ 无法获取 AudioRepo 实例")
                            }
                            return
                        }

                        await repo.deleteAudios(urls, verbose: Self.verbose)

                        // 发送文件系统删除完成事件
                        NotificationCenter.postFileSystemDeleted()

                        if Self.verbose {
                            os_log("\(self.t)✅ 数据库删除完成")
                        }
                    }
                },
                onProgress: { _, _ in
                    // 对下载进度不感兴趣
                }
            )

            // 监控器已创建，任务将保持运行直到被取消
            // 我们立即恢复 continuation
            continuation.resume()
        }

        // 保持任务运行，直到被取消
        while await state.getRunning() {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 1000000000) // 每秒检查一次
        }

        if Self.verbose {
            os_log("\(self.t)✅ 文件系统监控任务正常结束")
        }
    }

    func cancel() {
        Task { @Sendable [weak self] in
            guard let self = self else { return }
            await self.state.setRunning(false)
        }

        monitor?.cancel()
        monitor = nil

        if Self.verbose {
            os_log("\(self.t)⏹️ 文件系统监控已停止")
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

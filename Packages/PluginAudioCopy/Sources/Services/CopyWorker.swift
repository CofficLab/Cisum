import MagicKit
#if os(macOS)
    import Foundation
    import MagicKit
    import OSLog
    import SwiftUI

    enum CopyWorkerCompletionPolicy {
        static func shouldPostFinished(remainingTaskCount: Int) -> Bool {
            remainingTaskCount == 0
        }
    }

    enum CopyWorkerTaskPolicy {
        static func shouldStartTask(isTaskStillQueued: Bool) -> Bool {
            isTaskStillQueued
        }

        static func shouldKeepCompletedCopy(isTaskStillQueued: Bool) -> Bool {
            isTaskStillQueued
        }
    }

    @MainActor
    class CopyWorker: SuperLog {
        nonisolated static let emoji = "👷"

        let fm = FileManager.default
        let db: CopyDB
        var running = false
        let verbose: Bool = false

        init(db: CopyDB, reason: String) {
            if verbose {
                os_log("\(Self.t)🚀 (\(reason)) 初始化")
            }

            self.db = db
        }

        func append(tasks: [(bookmark: Data, filename: String)], folder: URL) async {
            await db.addCopyTasks(tasks: tasks, folder: folder)

            // 发送任务数量变化事件
            let count = await db.allCopyTaskDTOs().count
            NotificationCenter.postCopyTaskCountChanged(count: count)

            await self.run()
        }

        func run() async {
            if running {
                return
            }

            running = true

            if verbose {
                os_log("\(self.t)🚀 Run")
            }

            let allTasks = await db.allCopyTaskDTOs()
            let tasks = allTasks.filter { $0.error.isEmpty }
            let taskCount = tasks.count

            if tasks.isEmpty {
                self.running = false
                if verbose {
                    os_log("\(self.t)🎉 Done")
                }
                NotificationCenter.postCopyTaskCountChanged(count: allTasks.count)
                return
            }

            // 发送任务开始事件
            do {
                try await db.setTasksRunning(bookmarks: tasks.map(\.bookmark))
            } catch {
                os_log(.error, "\(self.t)Failed to mark tasks running: \(error.localizedDescription)")
            }
            NotificationCenter.postCopyTaskStarted(count: taskCount)

            // 使用 Actor 隔离的计数器追踪完成数量
            let completedCount = ActorCompletedCounter()

            let plannedDestinations = Self.makeUniqueDestinationURLs(for: tasks)
            let plannedTasks = Array(zip(tasks, plannedDestinations))

            await withTaskGroup(of: Bool.self) { group in
                for (task, destination) in plannedTasks {
                    group.addTask {
                        var stale = false
                        var didComplete = false

                        do {
                            guard await Self.shouldStartTask(isTaskStillQueued: self.db.hasCopyTask(bookmark: task.bookmark)) else {
                                return false
                            }

                            // Resolve the bookmark to get a security-scoped URL
                            guard let url = try? URL(resolvingBookmarkData: task.bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) else {
                                throw NSError(
                                    domain: "CopyWorker",
                                    code: 0,
                                    userInfo: [
                                        NSLocalizedDescriptionKey: String(localized: "The original file can no longer be accessed", bundle: .module)
                                    ]
                                )
                            }

                            let securityScopeGranted = url.startAccessingSecurityScopedResource()
                            guard Self.hasCopySourceAccess(url, securityScopeGranted: securityScopeGranted) else {
                                throw NSError(
                                    domain: "CopyWorker",
                                    code: 1,
                                    userInfo: [
                                        NSLocalizedDescriptionKey: String(localized: "Permission to access the original file was denied", bundle: .module)
                                    ]
                                )
                            }

                            defer {
                                if securityScopeGranted {
                                    url.stopAccessingSecurityScopedResource()
                                }
                            }

                            if self.verbose {
                                os_log("\(self.t)🍋 [\(task.originalFilename)] 开始复制，共 \(taskCount)")
                            }

                            let sourceToCopy = Self.copySourceURL(for: url)
                            try await sourceToCopy.copyTo(destination, verbose: self.verbose, caller: self.className)

                            guard await Self.shouldKeepCompletedCopy(isTaskStillQueued: self.db.hasCopyTask(bookmark: task.bookmark)) else {
                                try? FileManager.default.removeItem(at: destination)
                                return false
                            }

                            if self.verbose {
                                os_log("\(self.t)🎉 [\(task.originalFilename)] Copied to \(destination.lastPathComponent)")
                            }

                            try await self.db.deleteCopyTasks(bookmarks: [task.bookmark])
                            didComplete = true
                        } catch let e {
                            os_log(.error, "\(self.t)\(e)")
                            await self.db.setTaskError(bookmark: task.bookmark, error: e.localizedDescription)
                        }

                        // 记录完成
                        if didComplete {
                            await completedCount.increment()
                        }

                        return didComplete
                    }
                }

                // 等待所有任务完成
                var completed = 0
                for await didComplete in group {
                    if didComplete {
                        completed += 1
                    }
                }

                if verbose {
                    os_log("\(self.t)✅ Completed: \(completed)/\(taskCount)")
                }
            }

            self.running = false

            // 检查剩余任务数量，发送完成事件
            let remainingTasks = await db.allCopyTaskDTOs()
            let remainingCount = remainingTasks.count
            let pendingCount = remainingTasks.filter { $0.error.isEmpty }.count
            if verbose {
                os_log("\(self.t)📊 Remaining: \(remainingCount)")
            }

            if remainingCount == 0 {
                // 延迟1秒后发送完成事件
                try? await Task.sleep(nanoseconds: 1000000000)
                let delayedRemainingTasks = await db.allCopyTaskDTOs()
                guard Self.shouldPostFinished(afterDelayRemainingTasks: delayedRemainingTasks) else {
                    NotificationCenter.postCopyTaskCountChanged(count: delayedRemainingTasks.count)
                    if delayedRemainingTasks.contains(where: { $0.error.isEmpty }) {
                        await self.run()
                    }
                    return
                }
                NotificationCenter.postCopyTaskFinished(count: 0, lastCount: taskCount)
            } else if pendingCount > 0 {
                // 还有任务，发送数量更新事件
                NotificationCenter.postCopyTaskCountChanged(count: remainingCount)

                await self.run()
            } else {
                NotificationCenter.postCopyTaskCountChanged(count: remainingCount)
            }
        }

        nonisolated static func shouldPostFinished(afterDelayRemainingTasks tasks: [CopyTaskDTO]) -> Bool {
            CopyWorkerCompletionPolicy.shouldPostFinished(remainingTaskCount: tasks.count)
        }

        nonisolated static func shouldStartTask(isTaskStillQueued: Bool) -> Bool {
            CopyWorkerTaskPolicy.shouldStartTask(isTaskStillQueued: isTaskStillQueued)
        }

        nonisolated static func shouldKeepCompletedCopy(isTaskStillQueued: Bool) -> Bool {
            CopyWorkerTaskPolicy.shouldKeepCompletedCopy(isTaskStillQueued: isTaskStillQueued)
        }

        nonisolated static func hasCopySourceAccess(_ source: URL, securityScopeGranted: Bool) -> Bool {
            securityScopeGranted || FileManager.default.isReadableFile(atPath: source.path)
        }

        nonisolated static func makeUniqueDestinationURLs(
            for tasks: [CopyTaskDTO],
            fileExists: (URL) -> Bool = CopyWorker.pathExistsIncludingSymlink
        ) -> [URL] {
            var reservedPaths = Set<String>()

            return tasks.map { task in
                uniqueDestinationURL(
                    for: task.originalFilename,
                    in: task.destination,
                    reservedPaths: &reservedPaths,
                    fileExists: fileExists
                )
            }
        }

        nonisolated private static func uniqueDestinationURL(
            for filename: String,
            in folder: URL,
            reservedPaths: inout Set<String>,
            fileExists: (URL) -> Bool
        ) -> URL {
            let baseURL = folder.appendingPathComponent(filename)
            let pathExtension = baseURL.pathExtension
            let baseName = baseURL.deletingPathExtension().lastPathComponent

            var candidate = baseURL
            var suffix = 2
            while reservedPaths.contains(candidate.path) || fileExists(candidate) {
                let nextName: String
                if pathExtension.isEmpty {
                    nextName = "\(baseName) \(suffix)"
                } else {
                    nextName = "\(baseName) \(suffix).\(pathExtension)"
                }
                candidate = folder.appendingPathComponent(nextName)
                suffix += 1
            }

            reservedPaths.insert(candidate.path)
            return candidate
        }

        nonisolated private static func pathExistsIncludingSymlink(_ url: URL) -> Bool {
            if FileManager.default.fileExists(atPath: url.path) {
                return true
            }

            return (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
        }

        nonisolated static func copySourceURL(for source: URL) -> URL {
            let resolvedSource = source.resolvingSymlinksInPath().standardizedFileURL
            guard FileManager.default.fileExists(atPath: resolvedSource.path) else {
                return source
            }

            return resolvedSource
        }
    }

    /// Actor 隔离的计数器，用于并发安全地计数
    actor ActorCompletedCounter {
        private var count: Int = 0

        func increment() {
            count += 1
        }

        func getCount() -> Int {
            count
        }
    }
#endif

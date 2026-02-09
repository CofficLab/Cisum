#if os(macOS)
    import Foundation
    import MagicKit
    import OSLog
    import SwiftUI

    @MainActor
    class CopyWorker: SuperLog {
        nonisolated static let emoji = "👷"

        let fm = FileManager.default
        let db: CopyDB
        var running = false
        let verbose: Bool = true

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

            let tasks = await db.allCopyTaskDTOs()
            let taskCount = tasks.count

            if tasks.isEmpty {
                self.running = false
                if verbose {
                    os_log("\(self.t)🎉 Done")
                }
                return
            }

            // 发送任务开始事件
            NotificationCenter.postCopyTaskStarted(count: taskCount)

            // 使用 Actor 隔离的计数器追踪完成数量
            let completedCount = ActorCompletedCounter()

            await withTaskGroup(of: Bool.self) { group in
                for task in tasks {
                    group.addTask {
                        var stale = false
                        var didComplete = false

                        do {
                            // Resolve the bookmark to get a security-scoped URL
                            guard let url = try? URL(resolvingBookmarkData: task.bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) else {
                                throw NSError(domain: "CopyWorker", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to resolve bookmark"])
                            }

                            // Start accessing the resource
                            guard url.startAccessingSecurityScopedResource() else {
                                throw NSError(domain: "CopyWorker", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to start accessing security-scoped resource"])
                            }

                            // Ensure we stop accessing the resource when we're done
                            defer { url.stopAccessingSecurityScopedResource() }

                            let destination = task.destination.appendingPathComponent(task.originalFilename)

                            // 已经存在了，则忽略
                            if destination.isFileExist {
                                if self.verbose {
                                    os_log("\(self.t)⏭️ [\(task.originalFilename)] Skipping, file already exists")
                                }
                                // Delete the task as it's already completed.
                                await self.db.deleteCopyTasks(bookmarks: [task.bookmark])
                                didComplete = true
                            } else {
                                if self.verbose {
                                    os_log("\(self.t)🍋 [\(task.originalFilename)] 开始复制，共 \(taskCount)")
                                }

                                try await url.copyTo(destination, verbose: self.verbose, caller: self.className)

                                if self.verbose {
                                    os_log("\(self.t)🎉 [\(task.originalFilename)] Copied")
                                }

                                await self.db.deleteCopyTasks(bookmarks: [task.bookmark])
                                didComplete = true
                            }
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
            let remainingCount = await db.allCopyTaskDTOs().count
            if verbose {
                os_log("\(self.t)📊 Remaining: \(remainingCount)")
            }

            if remainingCount == 0 {
                // 延迟1秒后发送完成事件
                try? await Task.sleep(nanoseconds: 1000000000)
                NotificationCenter.postCopyTaskFinished(count: 0, lastCount: taskCount)
            } else {
                // 还有任务，发送数量更新事件
                NotificationCenter.postCopyTaskCountChanged(count: remainingCount)
                
                await self.run()
            }
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

    // MARK: Preview

    #Preview("App") {
        ContentView()
            .inRootView()
            .withDebugBar()
    }
#endif

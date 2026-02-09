import Foundation
import MagicKit

import OSLog
import SwiftData
import SwiftUI

actor CopyDB: ModelActor, ObservableObject, SuperLog, SuperEvent, SuperThread {
    static let emoji = "🛖"
    let modelContainer: ModelContainer
    let modelExecutor: any ModelExecutor
    let context: ModelContext
    let queue = DispatchQueue(label: "DB")
    var onUpdated: () -> Void = { os_log("🍋 DB::updated") }

    init(_ container: ModelContainer, reason: String, verbose: Bool) {
        if verbose {
            os_log("\(Self.i) 🐛 \(reason)")
        }

        modelContainer = container
        context = ModelContext(container)
        context.autosaveEnabled = false
        modelExecutor = DefaultSerialModelExecutor(
            modelContext: context
        )
    }

    func setOnUpdated(_ callback: @escaping () -> Void) {
        onUpdated = callback
    }

    func hasChanges() -> Bool {
        context.hasChanges
    }

    func insertCopyTask(_ task: CopyTask) {
        context.insert(task)
        try? context.save()
    }

    func addCopyTasks(tasks: [(bookmark: Data, filename: String)], folder: URL) {
        for taskInfo in tasks {
            newCopyTask(bookmark: taskInfo.bookmark, destination: folder, originalFilename: taskInfo.filename)
        }
    }

    /// 将文件从外部复制到应用中
    func newCopyTask(bookmark: Data, destination: URL, originalFilename: String) {
        if self.findCopyTask(bookmark: bookmark) != nil {
            return
        }

        let task = CopyTask(bookmark: bookmark, destination: destination, originalFilename: originalFilename)
        context.insert(task)
        do {
            try context.save()
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }
    }

    func deleteCopyTask(_ id: CopyTask.ID) {
        os_log("\(self.t)数据库删除")
        let context = ModelContext(modelContainer)
        guard let task = context.model(for: id) as? CopyTask else {
            os_log("\(self.t)删除时数据库找不到")
            return
        }

        do {
            context.delete(task)

            try context.save()
            os_log("\(self.t)删除成功")
        } catch let e {
            os_log("\(self.t)删除出错 \(e)")
        }
    }

    func deleteCopyTasks(bookmarks: [Data]) {
        try? self.context.delete(model: CopyTask.self, where: #Predicate {
            bookmarks.contains($0.bookmark)
        })

        do {
            try context.save()
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }
    }

    nonisolated func delete(_ task: CopyTask) {
        // os_log("\(Logger.isMain)🗑️ 删除复制任务 \(task.title)")
        let context = ModelContext(modelContainer)
        guard let t = context.model(for: task.id) as? CopyTask else {
            return os_log("\(self.t)🗑️ 删除时数据库找不到 \(task.title)")
        }

        do {
            context.delete(t)
            try context.save()
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }
    }

    func allCopyTasks() -> [CopyTask] {
        let descriptor = FetchDescriptor<CopyTask>()
        do {
            return try context.fetch(descriptor)
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }

        return []
    }

    /// 同步获取所有复制任务（供 UI 使用）
    /// - Parameter container: ModelContainer 实例
    /// - Returns: CopyTask 数组
    static func getAllTasks(from container: ModelContainer) -> [CopyTask] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CopyTask>()
        do {
            return try context.fetch(descriptor)
        } catch {
            os_log(.error, "Failed to fetch tasks: \(error.localizedDescription)")
            return []
        }
    }

    /// 同步删除指定的任务（供 UI 使用）
    /// - Parameters:
    ///   - tasks: 要删除的任务数组
    ///   - container: ModelContainer 实例
    static func deleteTasks(_ tasks: [CopyTask], from container: ModelContainer) {
        let context = ModelContext(container)
        for task in tasks {
            context.delete(task)
        }
        do {
            try context.save()
        } catch {
            os_log(.error, "Failed to delete tasks: \(error.localizedDescription)")
        }
    }

    func findCopyTask(bookmark: Data) -> CopyTask? {
        let predicate = #Predicate<CopyTask> {
            $0.bookmark == bookmark
        }
        var descriptor = FetchDescriptor<CopyTask>(predicate: predicate)
        descriptor.fetchLimit = 1
        do {
            let result = try context.fetch(descriptor)
            return result.first
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }

        return nil
    }

    func setTaskRunning(_ task: CopyTask) {
        task.isRunning = true
        task.error = ""
        do {
            try context.save()
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }
    }

    func setTaskError(_ task: CopyTask, _ e: Error) {
        task.isRunning = false
        task.error = e.localizedDescription
        do {
            try context.save()
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }
    }

    func setTaskError(bookmark: Data, error: String) {
        if let task = findCopyTask(bookmark: bookmark) {
            setTaskError(task, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: error]))
        }
    }

    func allCopyTaskDTOs() async -> [CopyTaskDTO] {
        // 创建新context以确保获取最新数据
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CopyTask>()
        do {
            return try context.fetch(descriptor).map { CopyTaskDTO(from: $0) }
        } catch {
            os_log(.error, "Failed to fetch DTOs: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

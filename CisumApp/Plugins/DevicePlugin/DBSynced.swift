import Foundation
import OSLog
import SwiftData
import SwiftUI
import MagicKit


actor DBSynced: ModelActor, ObservableObject, SuperLog {
    static let emoji = "📦"

    let modelContainer: ModelContainer
    let modelExecutor: any ModelExecutor
    let context: ModelContext

    init(_ container: ModelContainer, verbose: Bool = false) {
        if verbose {
            let message = "\(Self.t)初始化"
            
            os_log("\(message)")
        }

        modelContainer = container
        context = ModelContext(container)
        context.autosaveEnabled = false
        modelExecutor = DefaultSerialModelExecutor(
            modelContext: context
        )
    }

    func hasChanges() -> Bool {
        context.hasChanges
    }
}

// MARK: 增加

extension DBSynced {
    func insertModel(_ model: any PersistentModel) throws {
        context.insert(model)
        try context.save()
    }
}

// MARK: 删除

extension DBSynced {
    func destroy<T>(for model: T.Type) throws where T: PersistentModel {
        try context.delete(model: T.self)
    }
}

// MARK: 修改

extension DBSynced {
    func save() {
        do {
            try context.save()
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }
    }

    func save(_ completion: @escaping (Error?) -> Void) {
        do {
            try context.save()
            completion(nil)
        } catch let error {
            completion(error)
        }
    }
}

// MARK: 查询

extension DBSynced {
    /// 所有指定的model
    func all<T: PersistentModel>() throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    /// 分页的方式查询model
    func paginate<T: PersistentModel>(page: Int) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    /// 获取指定条件的数量
    func getCount<T: PersistentModel>(for predicate: Predicate<T>) throws -> Int {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return try context.fetchCount(descriptor)
    }

    /// 按照指定条件查询多个model
    func get<T: PersistentModel>(for predicate: Predicate<T>) throws -> [T] {
        // os_log("\(self.isMain) 🏠 LocalDB.get")
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return try context.fetch(descriptor)
    }

    /// 某个model的总条数
    func count<T>(for model: T.Type) throws -> Int where T: PersistentModel {
        let descriptor = FetchDescriptor<T>(predicate: .true)
        return try context.fetchCount(descriptor)
    }
}

// MARK: 辅助类函数

extension DBSynced {
    /// 执行并输出耗时
    func printRunTime(_ title: String, tolerance: Double = 1, verbose: Bool = false, _ code: () -> Void) {
        if verbose {
            os_log("\(self.t)\(title)")
        }

        let startTime = DispatchTime.now()

        code()

        // 计算代码执行时间
        let nanoTime = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1000000000

        if verbose && timeInterval > tolerance {
            os_log("\(self.t)\(title) cost \(timeInterval) 秒 🐢🐢🐢")
        }
    }
}

#Preview {
    ContentView()
    .inRootView()
    #if os(macOS)
        .frame(height: 800)
    #endif
}

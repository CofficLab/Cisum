import Foundation
import OSLog
import SwiftData
import SwiftUI
import CisumUIComponents


public actor DBSynced: ModelActor, ObservableObject, SuperLog {

    public static let emoji = "📦"

    public let modelContainer: ModelContainer
    public let modelExecutor: any ModelExecutor
    public let context: ModelContext

    public init(_ container: ModelContainer, verbose: Bool = false) {
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

    public func hasChanges() -> Bool {
        context.hasChanges
    }
}

// MARK: 增加

extension DBSynced {
    public func insertModel(_ model: any PersistentModel) throws {
        context.insert(model)
        try context.save()
    }
}

// MARK: 删除

extension DBSynced {
    public func destroy<T>(for model: T.Type) throws where T: PersistentModel {
        try context.delete(model: T.self)
    }
}

// MARK: 修改

extension DBSynced {
    public func save() {
        do {
            try context.save()
        } catch let e {
            os_log(.error, "\(e.localizedDescription)")
        }
    }

    public func save(_ completion: @escaping (Error?) -> Void) {
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
    public func all<T: PersistentModel>() throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    /// 分页的方式查询model
    public func paginate<T: PersistentModel>(page: Int) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    /// 获取指定条件的数量
    public func getCount<T: PersistentModel>(for predicate: Predicate<T>) throws -> Int {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return try context.fetchCount(descriptor)
    }

    /// 按照指定条件查询多个model
    public func get<T: PersistentModel>(for predicate: Predicate<T>) throws -> [T] {
        // os_log("\(self.isMain) 🏠 LocalDB.get")
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return try context.fetch(descriptor)
    }

    /// 某个model的总条数
    public func count<T>(for model: T.Type) throws -> Int where T: PersistentModel {
        let descriptor = FetchDescriptor<T>(predicate: .true)
        return try context.fetchCount(descriptor)
    }
}

// MARK: 辅助类函数

extension DBSynced {
    /// 执行并输出耗时
    public func printRunTime(_ title: String, tolerance: Double = 1, verbose: Bool = false, _ code: () -> Void) {
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

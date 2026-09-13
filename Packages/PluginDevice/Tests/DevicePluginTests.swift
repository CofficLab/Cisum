import Foundation
import SwiftData
import Testing
@testable import PluginDevice
@testable import CisumDeviceData

// MARK: - DBSynced 测试辅助（actor 隔离内返回 Sendable 值）

extension DBSynced {
    /// 全部记录 uuid 列表（actor 内提取，避免跨隔离返回非 Sendable）。
    func allUUIDs() -> [String] {
        ((try? all() as [DeviceData]) ?? []).map(\.uuid).sorted()
    }

    func countAll() -> Int {
        (try? count(for: DeviceData.self)) ?? -1
    }

    func findUUID(_ uuid: String) -> String? {
        find(uuid)?.uuid
    }

    /// 按条件查询的 uuid 列表。
    func queryUUIDs(for predicate: Predicate<DeviceData>) -> [String] {
        ((try? get(for: predicate) as [DeviceData]) ?? []).map(\.uuid)
    }

    /// 保存并返回结果（闭包不跨 actor 边界）。
    func saveAndReport() -> (success: Bool, errorDescription: String?) {
        var success = false
        var errorDescription: String?
        save { error in
            success = error == nil
            errorDescription = error?.localizedDescription
        }
        return (success, errorDescription)
    }

    /// 若存在则删除指定 uuid 记录。
    func deleteDeviceIfExists(uuid: String) -> Bool {
        guard let device = find(uuid) else { return false }
        deleteDevice(device)
        return true
    }

    func deviceSnapshot(_ uuid: String) -> (times: Int, audioCount: Int)? {
        guard let device = find(uuid) else { return nil }
        return (device.timesOpened, device.audioCount)
    }

    func devicesUUIDs() -> [String] {
        allDevices().map(\.uuid).sorted()
    }
}

// MARK: - 测试

@Test
func dbSyncedExportsEmoji() {
    #expect(DBSynced.emoji == "📦")
}

@Test
func dbSyncedSaveClearsPendingChanges() async throws {
    let (_, db) = try await makeInMemoryDB()
    let item = DeviceData(uuid: "device-insert")
    try await db.insertModel(item)
    // insertModel 内部已保存：无未提交变更。
    #expect(!(await db.hasChanges()))
}

@Test
func dbSyncedInsertsAndFetchesAll() async throws {
    let (_, db) = try await makeInMemoryDB()
    try await db.insertModel(DeviceData(uuid: "d2"))
    try await db.insertModel(DeviceData(uuid: "d1"))

    #expect(await db.allUUIDs() == ["d1", "d2"])
    #expect(await db.countAll() == 2)
}

@Test
func dbSyncedCountsAndQueriesByPredicate() async throws {
    let (_, db) = try await makeInMemoryDB()
    try await db.insertModel(DeviceData(uuid: "target"))

    let count = try await db.getCount(for: #Predicate<DeviceData> { $0.uuid == "target" })
    #expect(count == 1)

    let matches = await db.queryUUIDs(for: #Predicate<DeviceData> { $0.uuid == "target" })
    #expect(matches == ["target"])
}

@Test
func dbSyncedDestroyDeletesAll() async throws {
    let (_, db) = try await makeInMemoryDB()
    try await db.insertModel(DeviceData(uuid: "d1"))
    try await db.insertModel(DeviceData(uuid: "d2"))

    try await db.destroy(for: DeviceData.self)
    #expect(await db.countAll() == 0)
}

@Test
func dbSyncedSaveWithCompletionReportsErrors() async throws {
    let (_, db) = try await makeInMemoryDB()
    let result = await db.saveAndReport()
    #expect(result.success)
    #expect(result.errorDescription == nil)
}

@Test
func insertDeviceDataPersistsRecord() async throws {
    let (_, db) = try await makeInMemoryDB()
    await db.insertDeviceData(deviceId: "device-new")
    #expect(await db.findUUID("device-new") == "device-new")
}

@Test
func saveDeviceDataIncrementsTimesOpened() async throws {
    let (_, db) = try await makeInMemoryDB()
    await db.insertDeviceData(deviceId: "device-count")
    await db.saveDeviceData(uuid: "device-count", audioCount: 5)

    #expect(await db.deviceSnapshot("device-count")?.times == 1)
    #expect(await db.deviceSnapshot("device-count")?.audioCount == 5)

    await db.saveDeviceData(uuid: "device-count", audioCount: 7)
    #expect(await db.deviceSnapshot("device-count")?.times == 2)
}

@Test
func saveDeviceDataInsertsWhenMissing() async throws {
    let (_, db) = try await makeInMemoryDB()
    await db.saveDeviceData(uuid: "device-missing", audioCount: 3)
    #expect(await db.findUUID("device-missing") == "device-missing")
}

@Test
func deleteDeviceRemovesRecord() async throws {
    let (_, db) = try await makeInMemoryDB()
    await db.insertDeviceData(deviceId: "device-del")

    let deleted = await db.deleteDeviceIfExists(uuid: "device-del")
    #expect(deleted)
    #expect(await db.findUUID("device-del") == nil)
}

@Test
func allDevicesReturnsRecords() async throws {
    let (_, db) = try await makeInMemoryDB()
    await db.insertDeviceData(deviceId: "b")
    await db.insertDeviceData(deviceId: "a")

    #expect(await db.devicesUUIDs() == ["a", "b"])
}

@Test
func printRunTimeRunsClosure() async throws {
    let (_, db) = try await makeInMemoryDB()
    var ran = false
    await db.printRunTime("tolerance test", verbose: true) { ran = true }
    #expect(ran)
}

/// 内存 SwiftData 容器 + DBSynced。
private func makeInMemoryDB() async throws -> (ModelContainer, DBSynced) {
    let schema = Schema([DeviceData.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let db = DBSynced(container)
    return (container, db)
}

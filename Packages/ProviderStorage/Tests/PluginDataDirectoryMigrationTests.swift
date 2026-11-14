import Foundation
import Testing
@testable import CisumProviderStorage

@Suite("插件数据目录迁移")
struct PluginDataDirectoryMigrationTests {
    /// 迁移只在「旧目录存在且新目录不存在」时发生。
    @Test
    func migratesLegacyDirectoryWhenCurrentIsMissing() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let legacy = root.appendingPathComponent("legacy", isDirectory: true)
        let current = root.appendingPathComponent("PluginX", isDirectory: true)
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        let payload = legacy.appendingPathComponent("data.db")
        try Data("payload".utf8).write(to: payload)

        let migrated = PluginDataDirectoryMigration.migrate(from: legacy, to: current)

        #expect(migrated)
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
        #expect(FileManager.default.fileExists(atPath: current.path))
        // 旧目录里的内容必须一起搬过去，否则用户会看到数据消失。
        #expect(FileManager.default.fileExists(atPath: current.appendingPathComponent("data.db").path))
    }

    /// 新目录已存在时不迁移：宁可留下孤儿旧目录，也不覆盖用户的新数据。
    @Test
    func skipsWhenCurrentDirectoryAlreadyExists() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let legacy = root.appendingPathComponent("legacy", isDirectory: true)
        let current = root.appendingPathComponent("PluginX", isDirectory: true)
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
        let currentPayload = current.appendingPathComponent("data.db")
        try Data("new".utf8).write(to: currentPayload)

        let migrated = PluginDataDirectoryMigration.migrate(from: legacy, to: current)

        #expect(!migrated)
        #expect(FileManager.default.fileExists(atPath: legacy.path))
        // 新目录的内容必须保持原样。
        #expect(try Data(contentsOf: currentPayload) == Data("new".utf8))
    }

    /// 旧目录不存在时直接返回，不报错。
    @Test
    func skipsWhenLegacyDirectoryIsMissing() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let legacy = root.appendingPathComponent("missing", isDirectory: true)
        let current = root.appendingPathComponent("PluginX", isDirectory: true)

        let migrated = PluginDataDirectoryMigration.migrate(from: legacy, to: current)

        #expect(!migrated)
        #expect(!FileManager.default.fileExists(atPath: current.path))
    }

    /// 链式迁移：目录名改过多轮时，从**最早**的历史目录一路搬到当前目录。
    ///
    /// 这是插件 id 从「类型名」改为「反向 DNS」后的真实场景：
    /// `audio` → `AudioDBDataPlugin` → `com.coffic.cisum.plugin.audio-db-data`。
    @Test
    func migratesFromEarliestLegacyDirectoryInChain() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let earliest = root.appendingPathComponent("audio", isDirectory: true)
        try FileManager.default.createDirectory(at: earliest, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: earliest.appendingPathComponent("audio.db"))

        let pluginID = "com.coffic.cisum.plugin.audio-db-data"
        let current = root.appendingPathComponent(pluginID, isDirectory: true)

        let migrated = PluginDataDirectoryMigration.migrate(
            legacyDirectoryNames: ["audio", "AudioDBDataPlugin"],
            pluginID: pluginID,
            dataRootDirectory: root
        )

        #expect(migrated)
        #expect(!FileManager.default.fileExists(atPath: earliest.path))
        #expect(FileManager.default.fileExists(atPath: current.path))
        #expect(FileManager.default.fileExists(atPath: current.appendingPathComponent("audio.db").path))
    }

    /// 链式迁移：中间那轮的历史目录存在时，也应被搬到当前目录。
    @Test
    func migratesFromIntermediateLegacyDirectoryInChain() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let intermediate = root.appendingPathComponent("AudioDBDataPlugin", isDirectory: true)
        try FileManager.default.createDirectory(at: intermediate, withIntermediateDirectories: true)
        try Data("mid".utf8).write(to: intermediate.appendingPathComponent("audio.db"))

        let pluginID = "com.coffic.cisum.plugin.audio-db-data"
        let current = root.appendingPathComponent(pluginID, isDirectory: true)

        let migrated = PluginDataDirectoryMigration.migrate(
            legacyDirectoryNames: ["audio", "AudioDBDataPlugin"],
            pluginID: pluginID,
            dataRootDirectory: root
        )

        #expect(migrated)
        #expect(!FileManager.default.fileExists(atPath: intermediate.path))
        #expect(FileManager.default.fileExists(atPath: current.appendingPathComponent("audio.db").path))
    }

    /// 链式迁移：所有历史目录都不存在时，什么都不做。
    @Test
    func chainMigrationIsNoOpWhenNoLegacyDirectoryExists() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let pluginID = "com.coffic.cisum.plugin.audio-db-data"
        let migrated = PluginDataDirectoryMigration.migrate(
            legacyDirectoryNames: ["audio", "AudioDBDataPlugin"],
            pluginID: pluginID,
            dataRootDirectory: root
        )

        #expect(!migrated)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(pluginID).path))
    }

    /// 链式迁移：新目录已有内容时，不动任何历史目录。
    @Test
    func chainMigrationSkipsWhenCurrentDirectoryHasContent() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let legacy = root.appendingPathComponent("audio", isDirectory: true)
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: legacy.appendingPathComponent("audio.db"))

        let pluginID = "com.coffic.cisum.plugin.audio-db-data"
        let current = root.appendingPathComponent(pluginID, isDirectory: true)
        try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
        try Data("new".utf8).write(to: current.appendingPathComponent("audio.db"))

        let migrated = PluginDataDirectoryMigration.migrate(
            legacyDirectoryNames: ["audio", "AudioDBDataPlugin"],
            pluginID: pluginID,
            dataRootDirectory: root
        )

        #expect(!migrated)
        #expect(FileManager.default.fileExists(atPath: legacy.path))
        // 新目录的内容必须保持原样。
        #expect(
            try Data(contentsOf: current.appendingPathComponent("audio.db")) == Data("new".utf8)
        )
    }

    /// 旧路径是文件而不是目录时不迁移。
    @Test
    func skipsWhenLegacyPathIsAFile() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let legacy = root.appendingPathComponent("legacy")
        let current = root.appendingPathComponent("PluginX", isDirectory: true)
        try Data("file".utf8).write(to: legacy)

        let migrated = PluginDataDirectoryMigration.migrate(from: legacy, to: current)

        #expect(!migrated)
        #expect(FileManager.default.fileExists(atPath: legacy.path))
    }
}

private func temporaryRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ProviderStorageTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

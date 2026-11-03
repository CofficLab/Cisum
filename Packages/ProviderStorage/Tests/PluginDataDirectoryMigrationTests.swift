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

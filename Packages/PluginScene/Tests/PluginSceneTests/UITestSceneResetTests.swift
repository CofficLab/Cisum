import Foundation
import Testing
@testable import PluginScene

/// `--cisum-ui-testing-reset-scene` 的行为回归。
///
/// 有声书场景的 UI 回归用例需要「启动于音乐库 → 切到有声书」这条路径，
/// 而场景是**持久化**的：上一次运行停在有声书时，App 会直接以有声书启动，
/// 走的是另一条路径。因此 UI 测试需要一个开关，把本次启动固定在首个场景。
@MainActor
struct UITestSceneResetTests {

    /// 磁盘上持久化了「有声书」时，带开关的启动必须回到首个场景（音乐库）。
    @Test("带开关时忽略磁盘上持久化的场景")
    func resetSceneIgnoresPersistedScene() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginSceneReset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let persisted = tempDir.appendingPathComponent("current-scene.json")
        try Data(#"{"sceneName":"Audiobooks","pluginID":null}"#.utf8).write(to: persisted)

        let provider = SceneProvider(pluginDataDirectory: tempDir)
        provider.resetPersistedSceneForUITestingIfNeeded()

        #expect(provider.currentScene == .music, "带开关时必须回到首个场景（音乐库）")
    }

    /// 不带开关时，磁盘上持久化的场景照常恢复。
    @Test("不带开关时照常恢复持久化的场景")
    func withoutResetRestoresPersistedScene() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginSceneRestore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let persisted = tempDir.appendingPathComponent("current-scene.json")
        try Data(#"{"sceneName":"Audiobooks","pluginID":null}"#.utf8).write(to: persisted)

        let provider = SceneProvider(pluginDataDirectory: tempDir)
        provider.restoreCurrentScene()

        #expect(provider.currentScene == .audiobooks, "不带开关时必须照常恢复磁盘上的场景")
    }
}

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

    /// 不带开关时，磁盘上持久化的场景在可用场景列表中时照常恢复。
    ///
    /// 注意：当前有声书场景暂未上线，`scenes` 只返回 `[.music]`，
    /// 因此持久化的 `.audiobooks` 会被视为不可用而回落到首个场景。
    @Test("不带开关时恢复可用场景或回落到首个场景")
    func withoutResetRestoresAvailableSceneOrFallsBack() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginSceneRestore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let persisted = tempDir.appendingPathComponent("current-scene.json")
        // 持久化音乐场景（当前唯一启用的场景）
        try Data(#"{"sceneName":"Music Library","pluginID":null}"#.utf8).write(to: persisted)

        let provider = SceneProvider(pluginDataDirectory: tempDir)
        provider.restoreCurrentScene()

        #expect(provider.currentScene == .music, "必须恢复可用的音乐场景")
    }
}

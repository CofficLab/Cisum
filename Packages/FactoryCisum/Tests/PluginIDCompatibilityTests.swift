import Foundation
import KernelCore
import Testing
@testable import FactoryCisum

@Suite("插件 ID 兼容映射")
struct PluginIDCompatibilityTests {
    /// 所有新 id 必须是反向 DNS 形式。
    @Test
    func allNewIDsUseReverseDNSForm() {
        for (newID, _) in PluginIDCompatibility.legacyAliases {
            #expect(
                newID.hasPrefix("com.coffic.cisum.plugin."),
                "新 id 必须遵循反向 DNS 规范：\(newID)"
            )
            // 前缀之后至少有一段有意义的名字。
            #expect(newID.count > "com.coffic.cisum.plugin.".count, "新 id 缺少插件名：\(newID)")
        }
    }

    /// 旧 id 必须是改之前的类型名，不能与新 id 相同（否则映射无意义）。
    @Test
    func legacyIDsDifferFromNewIDs() {
        for (newID, legacyID) in PluginIDCompatibility.legacyAliases {
            #expect(newID != legacyID, "新旧 id 不应相同：\(newID)")
            #expect(!legacyID.isEmpty, "旧 id 不应为空：\(newID)")
        }
    }

    /// 别名表的键与值都不能重复——重复会导致某个插件的映射被覆盖。
    @Test
    func aliasTableHasNoDuplicates() {
        let values = Array(PluginIDCompatibility.legacyAliases.values)
        #expect(
            Set(values).count == values.count,
            "同一个旧 id 不应映射到多个新 id（后者会覆盖前者，导致状态丢失）"
        )
        #expect(
            Set(PluginIDCompatibility.legacyAliases.keys).count == PluginIDCompatibility.legacyAliases.count,
            "新 id 不应重复"
        )
    }

    /// 需要迁移磁盘目录的插件，其历史目录名不能与新 id 同名。
    @Test
    func legacyDirectoryNamesDifferFromNewID() {
        for (newID, names) in PluginIDCompatibility.legacyDirectoryNames {
            for name in names {
                #expect(name != newID, "历史目录名不应等于新 id：\(newID)")
                #expect(!name.isEmpty, "历史目录名不应为空：\(newID)")
            }
        }
    }

    /// 目录名映射的键必须是启用状态别名表里的 id（两者指向同一批插件）。
    @Test
    func directoryMigrationCoversOnlyKnownPlugins() {
        for newID in PluginIDCompatibility.legacyDirectoryNames.keys {
            #expect(
                PluginIDCompatibility.legacyAliases.keys.contains(newID),
                "需要迁移目录的插件 \(newID) 不在启用状态别名表中，两者应保持一致"
            )
        }
    }

    /// 端到端验证：内核在配置别名后，能用旧 id 存的状态恢复出启用状态。
    ///
    /// 这是整个迁移的关键断言——若它失败，用户升级后会发现所有插件被关掉。
    @MainActor
    @Test
    func kernelRestoresEnabledStateFromLegacyID() async throws {
        final class MemoryStateStore: PluginStatePersisting {
            private var values: [String: Bool] = [:]
            func enabledState(pluginID: String) -> Bool? { values[pluginID] }
            func setEnabled(_ enabled: Bool, pluginID: String) { values[pluginID] = enabled }
            func removeState(pluginID: String) { values.removeValue(forKey: pluginID) }
        }

        let kernel = KernelCoreContainer()
        let store = MemoryStateStore()
        kernel.stateStore = store
        kernel.legacyPluginIDAliases = PluginIDCompatibility.legacyAliases

        // 模拟旧版本：用户关掉了一个插件，状态以旧 id 为键落盘。
        let newID = "com.coffic.cisum.plugin.audio"
        let legacyID = try #require(PluginIDCompatibility.legacyAliases[newID])
        store.setEnabled(false, pluginID: legacyID)

        // 升级后：注册插件时，内核应回退到旧 id 读出「关闭」状态。
        try kernel.registerPlugin(ProbePlugin(id: newID, policy: .enabledByDefault))
        #expect(
            kernel.isPluginEnabled(id: newID) == false,
            "旧 id 的启用状态应被正确读回，否则升级后插件会被意外打开"
        )
    }

    /// 用户重新打开插件时，新旧两个 id 都应被写入（回滚旧版本仍兼容）。
    @MainActor
    @Test
    func persistingEnabledStateWritesBothNewAndLegacyID() async throws {
        final class MemoryStateStore: PluginStatePersisting {
            private var values: [String: Bool] = [:]
            func enabledState(pluginID: String) -> Bool? { values[pluginID] }
            func setEnabled(_ enabled: Bool, pluginID: String) { values[pluginID] = enabled }
            func removeState(pluginID: String) { values.removeValue(forKey: pluginID) }
        }

        let kernel = KernelCoreContainer()
        let store = MemoryStateStore()
        kernel.stateStore = store
        kernel.legacyPluginIDAliases = PluginIDCompatibility.legacyAliases

        let newID = "com.coffic.cisum.plugin.audio"
        let legacyID = try #require(PluginIDCompatibility.legacyAliases[newID])
        // 默认关闭：这样 enablePlugin 才会真正走一遍「写入启用状态」的路径。
        try kernel.registerPlugin(ProbePlugin(id: newID, policy: .disabledByDefault))
        try await kernel.startAsync(plugins: [])

        try await kernel.enablePlugin(id: newID)

        #expect(store.enabledState(pluginID: newID) == true)
        #expect(
            store.enabledState(pluginID: legacyID) == true,
            "旧 id 也应同步写入，保证回滚到旧版本时用户的开关仍然有效"
        )
    }

    /// 没有旧状态的插件不应被别名表误伤。
    @MainActor
    @Test
    func pluginWithoutStoredStateKeepsPolicyDefault() async throws {
        final class MemoryStateStore: PluginStatePersisting {
            func enabledState(pluginID: String) -> Bool? { nil }
            func setEnabled(_ enabled: Bool, pluginID: String) {}
            func removeState(pluginID: String) {}
        }

        let kernel = KernelCoreContainer()
        kernel.stateStore = MemoryStateStore()
        kernel.legacyPluginIDAliases = PluginIDCompatibility.legacyAliases

        let newID = try #require(PluginIDCompatibility.legacyAliases.keys.first)
        // 策略默认关闭，且没有任何历史状态 → 应保持关闭。
        try kernel.registerPlugin(ProbePlugin(id: newID, policy: .disabledByDefault))
        #expect(
            kernel.isPluginEnabled(id: newID) == false,
            "没有历史状态时不应凭空造出状态"
        )
    }
}

/// 用于验证启用状态读取的探针插件。
@MainActor
private final class ProbePlugin: SuperPlugin {
    let id: String
    let order: Int = 1
    let metadata: PluginMetadata

    init(id: String, policy: PluginEnablePolicy) {
        self.id = id
        self.metadata = PluginMetadata(
            id: id,
            name: "Probe",
            description: "",
            policy: policy
        )
    }
}

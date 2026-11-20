import CisumProviderStorage
import KernelCore
import LumiFactory
import LumiUI
import MagicKit
import ProviderTheme
import SwiftUI

/// Cisum 与共享装配引擎（LumiFactory）之间的全部差异。
///
/// 对齐 Wakey `WakeyManifest`：本文件是 Cisum 唯一的组合根声明，
/// 装配流水线（基线 Provider → 迁移 → 启动 → 接线）由 `KernelAssembler`
/// 统一解释，Cisum 不再维护自己的 Factory 包。
///
/// 钩子分工：
/// - `registerProviders`：App 域 Provider（AppState / 贡献聚合 / Cloud /
///   Device / 播放控制区）+ 主题桥接，在插件 boot 之前执行；
/// - `wireKernel`：启动完成后的视图注入、显隐协调与事件订阅。
@MainActor
enum CisumManifest {
    static let manifest = HostManifest(
        identity: HostIdentity(
            appName: "Cisum",
            loggerSubsystem: "com.coffic.cisum",
            mainWindowID: "cisum.main",
            settingsWindowID: "cisum.settings",
            accessibilityPrefix: "cisum",
            mainWindowMinimumSize: AppResponsivePlayerLayoutMetrics.shared.minimumWindowSize,
            mainWindowDefaultSize: CGSize(width: 400, height: 800),
            settingsWindowDefaultSize: CGSize(width: 900, height: 640)
        ),
        makePlugins: { CisumPluginFactory.makePlugins() },
        storage: HostStorageConfiguration(
            stateStorePluginID: "com.coffic.cisum.plugin.plugin-manager",
            // 数据根必须与 StoragePlugin 的 StorageProvider 同源：
            // MagicApp 内部已处理 UI 测试隔离根，这里先幂等重建隔离根
            // （必须早于任何目录读取），再按 Cisum 的命名规则拼数据根。
            dataRootDirectoryOverride: {
                UITestIsolation.resetIsolatedRootIfNeeded()
                return MagicApp.getAppSpecificSupportDirectory()
                    .appendingPathComponent(DataRootDirectoryNaming.directoryName(), isDirectory: true)
            },
            // 基础设施目录迁移（启用状态目录在装配期就要读）。
            // 各插件 boot 时还会做一次自身的幂等迁移，旧目录保留不动。
            legacyDirectoryMigrations: PluginDataDirectoryHistory.legacyDirectoryNames
        ),
        theme: HostThemeConfiguration(
            catalogThemeIDs: CisumThemeSelection.catalogueIDs,
            // 沿用 Cisum 历史目录名，延续用户已保存的主题选择。
            storageDirectoryName: "ThemeManager",
            migrateLegacySelection: { theme in
                guard let provider = theme as? DefaultThemeProviding else { return }
                CisumThemeBridge.migrateLegacySelection(in: provider)
            }
        ),
        legacyPluginIDAliases: CisumPluginIDCompatibility.legacyAliases,
        registerProviders: { kernel in
            try CisumHostProviders.register(in: kernel)
        },
        wireKernel: { kernel in
            CisumHostWiring.wire(kernel)
        },
        makeLoadingBrandOverlay: { AnyView(CisumLoadingBrandMark()) },
        features: HostFeatures(
            // 设置按钮由 SettingsButtonPlugin 贡献到工具栏 / 导航栏，
            // 不走宿主的通用工具栏设置项。
            showsSettingsToolbarButton: false,
            // UI 测试依赖大量后代 AX 标识；容器级 id 会传播遮蔽后代，
            // 就绪锚点用 `<prefix>.kernel.ready` / `<prefix>.settings.ready`。
            appliesWindowContentIdentifiers: false,
            // Cisum 是播放器布局（控制区 + 内容区），区域接线由
            // CisumHostWiring 按自己的 Provider 契约完成。
            skipsSharedRootViewWiring: true
        )
    )
}
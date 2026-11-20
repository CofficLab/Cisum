import KernelCore
import MagicKit
import ProviderAppState
import ProviderCloud
import ProviderCloudDownload
import ProviderContentView
import ProviderControlView
import ProviderDevice
import ProviderPlugin
import ProviderTheme
import SwiftUI

/// App 域 Provider 注册（`HostManifest.registerProviders` 钩子）。
///
/// 在插件 boot 之前执行；跨 App 一致的基础设施（存储 / 主题 / 设置 /
/// Toast / 磁盘缓存 / 插件管理）已由装配引擎的基线注册，这里只补
/// Cisum 特有的部分。
@MainActor
enum CisumHostProviders {
    static func register(in kernel: KernelCoreContainer) throws {
        // UI 测试注入：必须在任何插件 boot 之前完成，否则播放插件可能在
        // 安装替身之前就已经发起过 iCloud 下载。无参数时不做任何改动。
        // （隔离数据根的重建在 manifest 的 dataRootDirectoryOverride 里，
        // 早于基线 Storage Provider 创建。）
        ICloudDownloadControl.shared.bootstrapFromLaunchArguments()

        // UI 测试下显隐偏好必须与「隔离存储根」同源隔离：
        // `UserDefaults.standard` 是进程级全局状态，跨用例共享。
        let appState = BasicAppStateService(
            defaults: UITestIsolation.isolatedDefaults() ?? .standard
        )
        try kernel.registerProvider((any AppStateProviding).self, appState)

        // 同一实例按两个协议类型分别注册：宿主经 PluginProviding 查询聚合结果，
        // 插件经 PluginContributionProviding 在 onBoot 登记贡献。只注册其一会导致
        // 所有插件贡献（工具栏按钮/标签页/状态/主题等）解析失败、静默丢失。
        let pluginService = PluginContributionService(kernel: kernel)
        try kernel.registerProvider((any PluginProviding).self, pluginService)
        try kernel.registerProvider((any PluginContributionProviding).self, pluginService)

        // 播放引擎由 PluginPlayBack 插件在 onBoot 阶段创建并注册为 PlaybackProviding。

        try kernel.registerProvider((any CloudProviding).self, CloudService())
        // iCloud 文件下载进度：与账户可用性分开注册，因为它广播的是高频、
        // 文件粒度的变化，且由独立的 NSMetadataQuery 支撑。
        try kernel.registerProvider((any CloudDownloadProviding).self, CloudDownloadService())
        try kernel.registerProvider((any DeviceProviding).self, DeviceService())

        try kernel.registerProvider(
            (any ControlViewProviding).self,
            DefaultControlViewProvider(
                stateViews: { kernel.resolveProvider((any PluginProviding).self)?.getStateViews() ?? [] },
                stateMessage: { kernel.resolveProvider((any AppStateProviding).self)?.stateMessage ?? "" }
            )
        )

        // macOS 基线已注册 ContentViewProviding；iOS 基线没有，这里补上。
        if !kernel.isProviderRegistered((any ContentViewProviding).self) {
            try kernel.registerProvider((any ContentViewProviding).self, DefaultContentViewProvider())
        }

        // 主题桥接必须在内核启动之前完成：加载页背景取自全局主题注册中心
        // （LumiUIThemeRegistry），晚桥接会让加载页用回退配色渲染、
        // 主界面再切到真实配色——启动瞬间出现一次明暗闪烁。
        // 目录主题的预注册与旧选择迁移已由装配引擎在更早一步完成。
        if let theme = kernel.resolveProvider((any ThemeProviding).self) as? DefaultThemeProviding {
            CisumThemeBridge.install(theme, in: kernel)
        }
    }
}
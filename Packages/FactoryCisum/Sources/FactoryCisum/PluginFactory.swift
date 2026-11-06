import LumiUI
import PluginSettingView
import KernelCore
import PluginAudio
import PluginAudioCopy
import PluginAudioDBData
import PluginAudioDBView
import PluginAudioDemo
import PluginAudioDownload
import PluginAudioLike
import PluginAudioPlayMode
import PluginAudioProgress
import PluginAudioScene
import PluginAudioSettings
import PluginAudioWidgetControl
import PluginBook
import PluginBookControlButtons
import PluginBookDBView
import PluginBookDBData
import PluginBookLike
import PluginBookPlayMode
import PluginBookProgress
import PluginBookScene
import PluginBookSettings
import PluginAudioControlButtons
import PluginAppDirectory
import PluginFileLog
import PluginLikeButton
import PluginOpenButton
import PluginToast
import PluginPlayBack
import PluginPlaybackHero
import PluginPluginManager
import PluginPlaybackProgress
import PluginRepositoryGuide
import PluginReset
import PluginScene
import PluginSettingGeneral
import PluginSettingsButton
import PluginStorage
import PluginStore
import PluginWelcome
import ProviderRootView

/// 产出各种插件的工厂协议（对齐 Lumi `FactoryLumi/PluginFactory.swift`）。
///
/// 集中管理插件的构造；`FactoryCisum.createKernel` 通过它产出插件并交给
/// `BuiltinPluginManager` 启动。宿主可实现该协议覆盖插件列表。
@MainActor
public protocol PluginFactory {
    /// 产出要启动的全部插件。
    ///
    /// 各插件在 `onBoot` 中解析内核已有 Provider 并注册自己的贡献
    /// （如 SettingGeneralPlugin 注册「通用」入口、PluginPluginManager 注册
    /// 「插件管理」入口）。
    func makePlugins() -> [any SuperPlugin]
}

/// 默认插件工厂：直接装配 Cisum 的全部内置插件（对齐 Lumi
/// `DefaultPluginFactory.makePlugins()` 的硬编码清单方式）。
///
/// 插件清单由 Factory 自身维护（不再经由宿主/Registry 注入），
/// Factory 是唯一知道"应用由哪些插件组成"的地方。
public struct DefaultPluginFactory: PluginFactory {
    public init() {}

    public func makePlugins() -> [any SuperPlugin] {
        var plugins: [any SuperPlugin] = [
            AudioDBDataPlugin.shared,
            AudioDBViewPlugin.shared,
            AudioDemoPlugin.shared,
            AudioDownloadPlugin.shared,
            AudioLikePlugin.shared,
            AudioPlayModePlugin.shared,
            AudioPlugin.shared,
            AudioProgressPlugin.shared,
            AudioScenePlugin.shared,
            AudioSettingsPlugin.shared,
            AudioWidgetControlPlugin.shared,
            BookControlButtonsPlugin.shared,
            BookDBDataPlugin.shared,
            BookDBViewPlugin.shared,
            BookLikePlugin.shared,
            BookPlayModePlugin.shared,
            BookPlugin.shared,
            BookProgressPlugin.shared,
            BookScenePlugin.shared,
            BookSettingsPlugin.shared,
        ]

        #if os(macOS)
        plugins.append(CopyPlugin.shared)
        plugins.append(FileLogPlugin.shared)
        #endif

        // 设置按钮两端都要装：
        // - macOS 贡献到窗口工具栏（点击 openWindow 打开设置窗口）；
        // - iOS 贡献到系统导航栏（点击广播 openSettings 通知，由宿主以 sheet 呈现）。
        plugins.append(SettingsButtonPlugin.shared)

        plugins.append(contentsOf: [
            PluginSettingView(id: "com.coffic.cisum.plugin.setting-view"),
            PluginPlayBack.shared,
            ScenePlugin.shared,
            LikeButtonPlugin.shared,
            OpenButtonPlugin.shared,
            ToastSuperPlugin(
                overlayInstaller: { kernel, center in
                    kernel.resolveProvider((any RootViewProviding).self)?.addOverlays([
                        RootOverlayItem(id: ToastSuperPlugin.overlayID, order: 10_000) { content in
                            ToastOverlay(content: content, center: center)
                        }
                    ])
                },
                overlayUninstaller: { kernel in
                    kernel.resolveProvider((any RootViewProviding).self)?
                        .removeOverlays(ids: [ToastSuperPlugin.overlayID])
                }
            ),
            // 共享远程包 LumiPluginPluginManager，注入 Cisum 品牌 id。
            //
            // policy: .disabled —— Cisum 的插件策略全是 alwaysOn / disabled，
            // 没有用户可配置的插件；插件管理器在本宿主不启用，内核启动时
            // 彻底排除它，设置侧边栏也就不会出现「插件管理」入口。
            PluginPluginManager(
                id: "com.coffic.cisum.plugin.plugin-manager",
                policy: .disabled
            ),
            StoragePlugin.shared,
            StorePlugin.shared,
            SystemPlugin.shared,
            SettingGeneralPlugin.shared,
            // 共享远程包 LumiPluginAppDirectory：设置界面的「我们的应用」入口，
            // 列出 Coffic Lab 旗下其他应用。注入 Cisum 品牌 id。
            AppDirectoryPlugin(id: "com.coffic.cisum.plugin.app-directory"),
            PlaybackHeroPlugin.shared,
            AudioControlButtonsPlugin.shared,
            PlaybackProgressPlugin.shared,
            RepositoryGuidePlugin.shared,
            WelcomePlugin.shared,
        ] as [any SuperPlugin])

        return plugins
    }
}

/// 按允许 ID 列表过滤的插件工厂（对齐 Lumi `SelectedPluginFactory`）。
///
/// 用于「只装配启用集合中的插件」的场景；运行期启停仍由内核的
/// override 机制 + 贡献重建驱动。
public struct SelectedPluginFactory: PluginFactory {
    private let base: any PluginFactory
    public let allowedPluginIDs: Set<String>

    public init(allowedPluginIDs: Set<String>) {
        self.allowedPluginIDs = allowedPluginIDs
        self.base = DefaultPluginFactory()
    }

    public init(allowedPluginIDs: Set<String>, base: any PluginFactory) {
        self.allowedPluginIDs = allowedPluginIDs
        self.base = base
    }

    public func makePlugins() -> [any SuperPlugin] {
        base.makePlugins().filter { allowedPluginIDs.contains($0.id) }
    }
}

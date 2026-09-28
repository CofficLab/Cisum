import CisumUIComponents
import LumiUI
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
import PluginFileLog
import PluginLikeButton
import PluginOpenButton
import PluginToast
import PluginPlayBack
import PluginPlaybackHero
import PluginPluginManager
import PluginPlaybackProgress
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
        plugins.append(SettingsButtonPlugin.shared)
        #endif

        plugins.append(contentsOf: [
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
            PluginPluginManager.shared,
            StoragePlugin.shared,
            StorePlugin.shared,
            SystemPlugin.shared,
            SettingGeneralPlugin.shared,
            PlaybackHeroPlugin.shared,
            AudioControlButtonsPlugin.shared,
            PlaybackProgressPlugin.shared,
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

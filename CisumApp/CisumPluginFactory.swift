import KernelCore
import PluginAbout
import PluginAudio
import PluginAudioControlButtons
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
import PluginBookDBData
import PluginBookDBView
import PluginBookLike
import PluginBookLoading
import PluginBookProgress
import PluginBookScene
import PluginBookSettings
import PluginCacheManager
import PluginFileLog
import PluginLikeButton
import PluginOpenButton
import PluginPlayBack
import PluginPlaybackHero
import PluginPlaybackProgress
import PluginPluginManager
import PluginRepositoryGuide
import PluginReset
import PluginRootView
import PluginScene
import PluginSettingGeneral
import PluginSettingView
import PluginSettingsButton
import PluginStorage
import PluginStore
import PluginToast
import PluginVideoLibrary
import PluginVideoPlayback
import PluginVideoRepository
import PluginWelcome
import ProviderRootView

/// Cisum 的内置插件清单。
///
/// 对齐 Wakey：插件清单是宿主差异的一部分，由 App target 维护，
/// 经 `HostManifest.makePlugins` 交给共享装配引擎。
@MainActor
enum CisumPluginFactory {
    static func makePlugins() -> [any SuperPlugin] {
        // 播放器根视图插件必须先于功能插件 boot：
        // 覆盖层插件（Toast 等）在自己的 boot 阶段就要解析 RootViewProviding。
        var plugins: [any SuperPlugin] = [
            RootViewPlugin(),
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
            BookLoadingPlugin.shared,
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
            // 默认 `.required` 策略：书库、视频库、欢迎页、仓库引导等模块
            // 已改为 `enabledByDefault`，设置侧边栏会出现「插件管理」入口；
            // 入口可见性由插件管理器的默认策略
            // `.onlyWhenConfigurablePluginsExist` 自动判断。
            PluginPluginManager(
                id: "com.coffic.cisum.plugin.plugin-manager"
            ),
            // 共享远程包 LumiPluginCacheManager：磁盘缓存管理设置入口。
            CacheManagerPlugin(id: "com.coffic.cisum.plugin.cache-manager"),
            StoragePlugin.shared,
            StorePlugin.shared,
            SystemPlugin.shared,
            SettingGeneralPlugin.shared,
            // 共享远程包 LumiPluginAbout：设置界面的「关于」入口。
            AboutPlugin(
                id: "com.coffic.cisum.plugin.about",
                configuration: AboutConfiguration(
                    officialWebsiteURLString: "https://coffic.cn/cisum",
                    privacyPolicyURLString: "https://coffic.cn/privacy",
                    termsOfServiceURLString: "https://coffic.cn/terms"
                )
            ),
            PlaybackHeroPlugin.shared,
            AudioControlButtonsPlugin.shared,
            PlaybackProgressPlugin.shared,
            RepositoryGuidePlugin.shared,
            WelcomePlugin.shared,
        ] as [any SuperPlugin])

        // 视频库场景：仓库（数据层）→ 播放（引擎层）→ 视频库 UI。
        // 顺序保证视频库插件 ready 时，两个 Provider 插件已经注册好能力。
        plugins.append(contentsOf: [
            PluginVideoRepository.shared,
            PluginVideoPlayback.shared,
            VideoLibraryPlugin.shared,
        ] as [any SuperPlugin])

        return plugins
    }
}
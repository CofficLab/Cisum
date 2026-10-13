import ProviderScene
import ProviderAudioLibrary
import ProviderDocsView
import ProviderPlayback
import CisumUIComponents
import LumiUI
import KernelCore
import ProviderPlugin
import ProviderStorage
import KitAppEvents
import MagicPlayMan
import ProviderSettingView
import SwiftUI

/// 播放插件：负责创建并持有 `MagicPlayMan` 播放引擎，将其作为
/// `PlaybackProviding` 注入内核，并维护当前播放文件的磁盘持久化与恢复。
///
/// 原先由 `FactoryCisum` 直接创建 `MagicPlayMan` 并 `registerPlayback`，
/// 现收拢到本插件的 `onBoot`：插件持有播放引擎生命周期，内核只看到
/// `PlaybackProviding` 能力；具体播放引擎不会泄漏到视图层。
///
/// ## 播放文件持久化
/// 内核存在场景概念（`AppScene` 固定枚举），因此当前播放文件按「场景 + 文件」
/// 持久化到 `<dataRootDirectory>/PluginPlayBack/current-playback.plist`：
/// - `onBoot` 时从 Lumi `StorageProviding` 解析数据根目录，创建 `PlaybackStateStore`；
/// - `onReady` 时创建 `PlaybackSceneObserver`（Observers 目录）订阅场景变动，
///   在启动与场景切换时恢复对应场景上次播放的文件（`autoPlay: false`，
///   仅加载不自动播放）；
/// - 播放引擎的 `.assetChanged` 事件把当前播放文件写入当前场景的槽位。
/// 该功能仅有此插件维护。
@MainActor
public final class PluginPlayBack: AsyncSuperPlugin {
    public let id = String(describing: PluginPlayBack.self)

    public static let shared = PluginPlayBack()
    public let order = 12
    public let iconName = "play.circle"
    public let metadata = PluginMetadata(
        id: String(describing: PluginPlayBack.self),
        name: String(localized: "Play", bundle: .module),
        version: "1.0.0",
        category: .system,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    /// 持有的播放引擎；onBoot 时创建并注册为 `PlaybackProviding`。
    nonisolated(unsafe) public private(set) var magicPlayMan: MagicPlayMan?
    nonisolated(unsafe) private var playbackProvider: PlaybackProvider?

    /// 当前播放文件的磁盘存储（onBoot 时从 Lumi StorageProviding 创建）。
    nonisolated(unsafe) private var stateStore: PlaybackStateStore?

    /// 场景观察者（onReady 时创建）：监听场景变动并按场景恢复/记录播放文件。
    nonisolated(unsafe) private var sceneObserver: PlaybackSceneObserver?

    /// 设置页 ViewModel 与场景观察者（onReady 时创建，设置页导航项注入同一实例）。
    nonisolated(unsafe) private var settingsViewModel: PluginPlayBackSettingsViewModel?
    nonisolated(unsafe) private var settingsSceneObserver: PlaybackSettingsSceneObserver?
    nonisolated(unsafe) private var settingsPlaybackObserver: PlaybackSettingsPlaybackObserver?

    /// 播放状态变化监听句柄（记录当前文件到当前场景的磁盘槽位）。
    nonisolated(unsafe) private var observerHandle: (any PlaybackProvidingObserverHandle)?

    public init() {}

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { PluginPlayBackAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { PluginPlayBackManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let entry = makeSettingEntry() { kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([entry]) }
        }
        let player = MagicPlayMan()
        magicPlayMan = player
        
        // 使用 PlaybackProvider 包装并注册为 PlaybackProviding
        let playbackProvider = PlaybackProvider(playback: player)
        self.playbackProvider = playbackProvider
        try kernel.registerProvider((any PlaybackProviding).self, playbackProvider)
        try kernel.registerProvider((any PlaybackMediaProviding).self, playbackProvider)

        // 持久化存储（order 12 在 StoragePlugin 之后，Lumi StorageProviding 已可用）
        guard let storage = kernel.resolveProvider((any ProviderStorage.StorageProviding).self) else { return }
        let store = PlaybackStateStore(rootDirectory: storage.dataRootDirectory)
        #if DEBUG
        // UI 测试隔离：清空上次运行遗留的「当前播放记录」，保证每次 UI 测试启动
        // 都处于确定的「无当前曲目」状态；否则场景切换/播放器收起类断言会被
        // 上一轮 UI 测试留下的记录污染（记录随 App 持久化，跨测试运行生效）。
        // 必须在 onReady 的场景观察者恢复之前完成。
        if ProcessInfo.processInfo.arguments.contains("--cisum-ui-testing") {
            for scene in AppScene.allCases {
                store.saveCurrentFile(nil, for: scene)
            }
        }
        #endif
        stateStore = store

        // 监听播放文件变化，记录到当前场景的磁盘槽位（场景由 sceneObserver 提供）
        observerHandle = playbackProvider.addObserver { [weak self] event in
            guard case .assetChanged(let url) = event else { return }
            self?.sceneObserver?.saveCurrentFile(url)
        }
    }

    /// 就绪阶段：此时 ScenePlugin 已恢复当前场景，创建场景观察者并恢复该场景
    /// 上次播放的文件（启动恢复 + 后续场景切换恢复都由它负责），同时安装设置页
    /// 的场景化状态。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        guard let player = magicPlayMan, let store = stateStore else { return }
        #if DEBUG
        // `--cisum-ui-testing-playback-file <name>`：把音频目录下的指定文件写入
        // 音乐场景槽位，让 App 启动即恢复播放该文件（UI 测试据此在启动阶段进入
        // 下载态，无需依赖 XCUITest 点击触发）。放在 onReady：跨插件 Provider
        // （AudioLibraryProviding）此时才保证注册完毕；必须在场景观察者恢复之前。
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--cisum-ui-testing-playback-file"),
           ProcessInfo.processInfo.arguments.indices.contains(index + 1) {
            if let library = kernel.resolveProvider((any AudioLibraryProviding).self),
               let disk = library.audioDisk {
                store.saveCurrentFile(disk.appendingPathComponent(ProcessInfo.processInfo.arguments[index + 1]), for: .music)
            }
        }
        #endif
        sceneObserver = PlaybackSceneObserver(
            scene: makeSceneCapability(kernel: kernel),
            player: player,
            store: store
        )
        installSettingsState(kernel: kernel)
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: ["playback"])
        observerHandle?.cancel()
        observerHandle = nil
        sceneObserver?.cancel()
        sceneObserver = nil
        settingsSceneObserver?.cancel()
        settingsSceneObserver = nil
        settingsPlaybackObserver?.cancel()
        settingsPlaybackObserver = nil
        settingsViewModel = nil
        stateStore = nil
        playbackProvider?.shutdown()
        kernel.unregisterProvider(PlaybackProviding.self)
        kernel.unregisterProvider((any PlaybackMediaProviding).self)
        playbackProvider = nil
        magicPlayMan = nil
    }

    // MARK: - Settings state assembly

    /// 组装场景能力：把内核 `SceneProviding` 收窄为本插件的 `PlaybackSceneCapability`。
    ///
    /// 场景 Provider 可能尚未注册（如 onReady 早于 ScenePlugin），此时退化为
    /// 「无当前场景」的能力，Observer 仍能安装并等待后续事件。
    @MainActor
    private func makeSceneCapability(kernel: KernelCoreContainer) -> PlaybackSceneCapabilityAdapter {
        PlaybackSceneCapabilityAdapter(scene: kernel.resolveProvider((any SceneProviding).self))
    }

    /// 创建并持有设置页的 ViewModel 与场景观察者（幂等）。
    @MainActor
    private func installSettingsState(kernel: KernelCoreContainer) {
        guard settingsSceneObserver == nil else { return }
        guard let viewModel = settingsViewModel ?? makeSettingsViewModel() else { return }
        let observer = PlaybackSettingsSceneObserver(
            scene: makeSceneCapability(kernel: kernel),
            viewModel: viewModel
        )
        let playbackObserver = PlaybackSettingsPlaybackObserver(
            playback: PlaybackSettingsCapabilityAdapter(playback: playbackProvider),
            viewModel: viewModel
        )
        settingsSceneObserver = observer
        settingsPlaybackObserver = playbackObserver
    }

    @MainActor
    private func makeSettingsViewModel() -> PluginPlayBackSettingsViewModel? {
        guard let store = stateStore else { return nil }
        let viewModel = PluginPlayBackSettingsViewModel(
            store: store,
            playback: PlaybackSettingsCapabilityAdapter(playback: playbackProvider)
        )
        settingsViewModel = viewModel
        return viewModel
    }

    /// 设置窗口入口：按场景展示各场景最近播放文件与当前播放详情。
    ///
    /// 视图只接收 `PluginPlayBackSettingsViewModel`，播放详情由
    /// `PlaybackSettingsPlaybackObserver` 根据 Provider 事件实时刷新
    /// （`currentURL` / `isPlaying` / `duration` / `currentTime`）。
    @MainActor
    public func makeSettingEntry() -> SettingEntryItem? {
        let viewModel = settingsViewModel ?? makeSettingsViewModel()
        guard let viewModel else { return nil }
        return SettingEntryItem(
            id: "playback",
            title: String(localized: "Current File", bundle: .module),
            systemImage: iconName,
            order: order,
            detail: {
            PluginPlayBackSettingView(viewModel: viewModel)
        }
        )
    }
}


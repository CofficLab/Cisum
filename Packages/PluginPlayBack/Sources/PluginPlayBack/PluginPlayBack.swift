import CisumUIComponents
import KernelCore
import MagicPlayMan
import ProviderDocsView
import ProviderPlayback
import ProviderScene
import ProviderStorage
import SwiftUI

/// 播放插件：负责创建并持有 `MagicPlayMan` 播放引擎，将其作为
/// `PlaybackProviding` 注入内核，并维护当前播放文件的磁盘持久化与恢复。
///
/// 原先由 `FactoryCisum` 直接创建 `MagicPlayMan` 并 `registerPlayback`，
/// 现收拢到本插件的 `onBoot`：插件持有播放引擎生命周期，内核通过
/// `kernel.playback` 解析到 `MagicPlayMan` 实例（UI 层仍可
/// `as? MagicPlayMan` 注入 `@EnvironmentObject`）。
///
/// ## 播放文件持久化
/// 内核存在场景概念（`AppScene` 固定枚举），因此当前播放文件按「场景 + 文件」
/// 持久化到 `<databaseRoot>/PluginPlayBack/current-playback.plist`：
/// - `onBoot` 时从 `kernel.storage` 解析数据库根目录，创建 `PlaybackStateStore`；
/// - `onReady` 时创建 `PlaybackSceneObserver`（Observers 目录）订阅场景变动，
///   在启动与场景切换时恢复对应场景上次播放的文件（`autoPlay: false`，
///   仅加载不自动播放）；
/// - 播放引擎的 `.assetChanged` 事件把当前播放文件写入当前场景的槽位。
/// 该功能仅有此插件维护。
public actor PluginPlayBack: SuperPlugin {
    public static let shared = PluginPlayBack()
    public static let metadata = PluginMetadata(
        displayName: String(localized: "Play", bundle: .module),
        description: String(localized: "Playback engine and playback-state management.", bundle: .module),
        iconName: "play.circle",
        order: 12,
        policy: .alwaysOn,
        category: .system
    )

    /// 持有的播放引擎；onBoot 时创建并注册为 `PlaybackProviding`。
    nonisolated(unsafe) public private(set) var magicPlayMan: MagicPlayMan?

    /// 当前播放文件的磁盘存储（onBoot 时从 kernel.storage 创建）。
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
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { PluginPlayBackAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { PluginPlayBackManualView() })
        }
    }

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        let player = MagicPlayMan()
        magicPlayMan = player
        try kernel.registerPlayback(player)

        // 持久化存储（order 12 在 StoragePlugin 之后，kernel.storage 已可用）
        guard let storage = kernel.storage else { return }
        let store = PlaybackStateStore(rootDirectory: storage.databaseRoot)
        stateStore = store

        // 监听播放文件变化，记录到当前场景的磁盘槽位（场景由 sceneObserver 提供）
        observerHandle = player.addObserver { [weak self] event in
            guard case .assetChanged(let url) = event else { return }
            self?.sceneObserver?.saveCurrentFile(url)
        }
    }

    /// 就绪阶段：此时 ScenePlugin 已恢复当前场景，创建场景观察者并恢复该场景
    /// 上次播放的文件（启动恢复 + 后续场景切换恢复都由它负责），同时安装设置页
    /// 的场景化状态。
    @MainActor
    public func onReady(kernel: CisumKernel) async throws {
        guard let player = magicPlayMan, let store = stateStore else { return }
        sceneObserver = PlaybackSceneObserver(scene: kernel.scene, player: player, store: store)
        installSettingsState(kernel: kernel)
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
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
        magicPlayMan = nil
    }

    // MARK: - Settings state assembly

    /// 创建并持有设置页的 ViewModel 与场景观察者（幂等）。
    @MainActor
    private func installSettingsState(kernel: CisumKernel) {
        guard settingsSceneObserver == nil else { return }
        guard let viewModel = settingsViewModel ?? makeSettingsViewModel() else { return }
        let observer = PlaybackSettingsSceneObserver(provider: kernel.scene, viewModel: viewModel)
        let playbackObserver = PlaybackSettingsPlaybackObserver(playback: kernel.playback, viewModel: viewModel)
        settingsSceneObserver = observer
        settingsPlaybackObserver = playbackObserver
    }

    @MainActor
    private func makeSettingsViewModel() -> PluginPlayBackSettingsViewModel? {
        guard let store = stateStore else { return nil }
        let viewModel = PluginPlayBackSettingsViewModel(
            store: store,
            playbackCapability: makePlaybackSettingsCapability(from: magicPlayMan)
        )
        settingsViewModel = viewModel
        return viewModel
    }

    @MainActor
    private func makePlaybackSettingsCapability(
        from playback: (any PlaybackProviding)?
    ) -> (any PlaybackSettingsCapability)? {
        guard let playback else { return nil }
        return PlaybackSettingsCapabilityAdapter(playback: playback)
    }

    /// 设置窗口入口：按场景展示各场景最近播放文件与当前播放详情。
    ///
    /// 注入 `PluginPlayBackSettingsViewModel` 作为环境数据（场景切换时刷新），
    /// 并注入 `MagicPlayMan` 作为环境对象，播放详情随播放状态实时刷新
    /// （`currentURL` / `isPlaying` / `duration` / `currentTime`）。
    @MainActor
    public func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        let viewModel = settingsViewModel ?? makeSettingsViewModel()
        guard let viewModel else { return nil }
        return PluginSettingNavigationItem(
            id: "playback",
            title: String(localized: "Current File", bundle: .module),
            description: Self.metadata.description,
            iconName: Self.metadata.iconName,
            order: Self.metadata.order,
            destination: AnyView(
                PluginPlayBackSettingView(viewModel: viewModel)
            )
        )
    }
}

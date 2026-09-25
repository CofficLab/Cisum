import ProviderAppState
import ProviderAudioLibrary
import ProviderScene
import ProviderDocsView
import ProviderPlayback
import ProviderStorage
import CisumKernelSupport
import SwiftUI
import MagicKit
import OSLog

@MainActor
public final class AudioDBViewPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: AudioDBViewPlugin.self)

    nonisolated static let verbose = false

    public static let shared = AudioDBViewPlugin()
    public let order = 1
    public let iconName = "externaldrive"
    public let metadata = PluginMetadata(
        id: String(describing: AudioDBViewPlugin.self),
        name: String(localized: String.LocalizationValue(AudioDBPluginInfo.titleKey), bundle: .module),
        description: String(localized: String.LocalizationValue(AudioDBPluginInfo.descriptionKey), bundle: .module),
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) private let sceneBox = SceneBox()
    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var listViewModel: AudioListViewModel?
    nonisolated(unsafe) private var rootViewModel: AudioDBRootViewModel?
    nonisolated(unsafe) private var dbViewModel: AudioDBViewModel?
    nonisolated(unsafe) private var databaseObserver: AudioDatabaseObserver?
    nonisolated(unsafe) private var playbackObserver: AudioDBPlaybackObserver?
    nonisolated(unsafe) private var settingPlaybackObserver: AudioDBPlaybackObserver?
    nonisolated(unsafe) private var sceneState: AudioDBSceneState?
    nonisolated(unsafe) private var sceneObserver: AudioDBSceneObserver?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { AudioDBPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { AudioDBPluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            contrib.addTabView { reason, demoMode in self.addTabView(reason: reason, demoMode: demoMode) }
            if let view = self.addSettingNavigationItem() { contrib.addSettingNavigationItem(view) }
        }
        self.kernel = kernel
        // 跨插件 Provider（Scene / Playback）一律在 onReady 中解析，不假设其他插件
        // 已完成 Provider 注册（对齐 `BookDBViewPlugin`）。
        //
        // 尤其不能在 onBoot 捕获 `SceneProviding`：`ScenePlugin`（order -1000）会在
        // 自己的 onReady 里用带持久化的新实例替换 onBoot 阶段注册的临时实例
        // （见 `ScenePlugin.onReady`）。onBoot 捕获到的旧实例随后失去唯一强引用被
        // 释放，`sceneBox.scene`（weak）变成 nil，`addTabView` 的场景守卫将恒为
        // false，音乐库内容区会退化成「当前场景暂无可用内容」。
    }

    /// 所有 Provider 插件完成 onBoot 后再组装依赖它们的 ViewModel 与 Observer。
    ///
    /// `PluginPlayBack` 同样在 onBoot 注册 PlaybackProviding，因此 AudioDB 不能
    /// 在自己的 onBoot 中假设播放服务已经存在；`SceneProviding` 则因为实例会在
    /// `ScenePlugin.onReady` 被替换，必须在此处（onReady）解析。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        installState(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        installState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        teardownState()
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        sceneBox.scene = nil
        teardownState()
    }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        let (list, root, db) = resolveViewModels()
        return AnyView(
            AudioDBPluginRootView(
                listViewModel: list,
                rootViewModel: root,
                dbViewModel: db,
                sceneState: resolveSceneState(),
                audioLibrary: audioLibraryProvider,
                audioDisk: audioDiskProvider,
                audioDiagnostics: audioDiagnosticsProvider,
                isDemoMode: kernel?.resolveProvider((any AppStateProviding).self)?.isDemoMode ?? false,
                isImporting: Binding(
                    get: { self.kernel?.resolveProvider((any AppStateProviding).self)?.isImporting ?? false },
                    set: { self.kernel?.resolveProvider((any AppStateProviding).self)?.setImporting($0) }
                ),
                showDBView: { self.kernel?.resolveProvider((any AppStateProviding).self)?.showDBView() },
                content: content
            )
        )
    }

    @MainActor
    public func addTabView(reason: String, demoMode: Bool = false) -> (view: AnyView, label: String)? {
        guard sceneBox.scene?.currentScene == .music else { return nil }
        guard demoMode == false else { return nil }

        let (list, root, db) = resolveViewModels()
        return (
            AnyView(AudioDBPluginTabView(
                listViewModel: list,
                rootViewModel: root,
                dbViewModel: db,
                audioLibrary: audioLibraryProvider,
                audioDisk: audioDiskProvider,
                audioDiagnostics: audioDiagnosticsProvider,
                isImporting: Binding(
                    get: { self.kernel?.resolveProvider((any AppStateProviding).self)?.isImporting ?? false },
                    set: { self.kernel?.resolveProvider((any AppStateProviding).self)?.setImporting($0) }
                ),
                showDBView: { self.kernel?.resolveProvider((any AppStateProviding).self)?.showDBView() },
                demoMode: demoMode
            )),
            String(localized: "Music Repository", bundle: .module)
        )
    }

    /// 设置窗口入口：展示音频库文件列表（方式一）与目录树（方式二）。
    @MainActor
    public func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        // 设置页使用独立的 AudioListViewModel，避免与主窗口内容区（AudioList）
        // 共享同一实例——否则设置页 onAppear 触发 handleOnAppear() 重载时，
        // 共享状态变化会传播到主窗口 contentview，导致其闪动。
        let playback = kernel?.resolveProvider((any PlaybackProviding).self)
        let settingList = AudioListViewModel(
            audioLibrary: audioLibraryProvider,
            playbackCapability: makePlaybackCapability(from: playback)
        )
        let settingTree = AudioTreeViewModel(disk: audioDiskProvider)
        settingPlaybackObserver = AudioDBPlaybackObserver(playback: playback, viewModel: settingList)
        return PluginSettingNavigationItem(
            id: "audiodb",
            title: String(localized: String.LocalizationValue(AudioDBPluginInfo.titleKey), bundle: .module),
            description: metadata.description,
            iconName: iconName,
            // 设置入口排序不使用 order（1 是启动优先级），
            // 使用独立值确保「通用」（order=1）排在最前。
            order: 10,
            destination: AnyView(
                AudioDBSettingView(
                    viewModel: settingList,
                    treeViewModel: settingTree,
                    dependencies: settingDependencies
                )
            )
        )
    }

    /// 设置页依赖：仓库路径 / 仓库 / 诊断由数据层 Provider 提供。
    @MainActor
    private var settingDependencies: AudioDBDependencies {
        AudioDBDependencies(
                audioLibrary: audioLibraryProvider,
            audioDisk: audioDiskProvider,
            audioDiagnostics: audioDiagnosticsProvider,
            supportedExtensions: AudioPluginInfo.supportedExtensions,
            isDesktop: Self.isDesktop,
            isNotDesktop: !Self.isDesktop,
            showDBView: { self.kernel?.resolveProvider((any AppStateProviding).self)?.showDBView() ?? () },
            isImporting: .constant(false)
        )
    }

    private static var isDesktop: Bool {
        #if os(macOS)
            true
        #else
            false
        #endif
    }

    // MARK: - Data Provider bridge

    /// 音频仓库闭包：从数据层 Provider 获取。
    @MainActor
    private var audioLibraryProvider: @MainActor @Sendable () -> (any AudioLibraryProviding)? {
        { @MainActor [weak self] in
            self?.kernel?.resolveProvider((any AudioLibraryProviding).self)
        }
    }

    /// 音频磁盘目录闭包：从数据层 Provider 获取。
    @MainActor
    private var audioDiskProvider: @MainActor @Sendable () -> URL? {
        { @MainActor [weak self] in
            self?.kernel?.resolveProvider((any AudioLibraryProviding).self)?.audioDisk
        }
    }

    /// 仓库路径解析诊断（错误视图展示）。
    @MainActor
    private var audioDiagnosticsProvider: @MainActor @Sendable () -> AudioStorageDiagnostics {
        { @MainActor [weak self] in
            AudioStorageDiagnosticsFactory.make(storage: self?.kernel?.resolveProvider((any StorageProviding).self))
        }
    }

    // MARK: - State assembly

    /// 将内核能力收窄后注入 ViewModel；ViewModel 不持有 Kernel。
    @MainActor
    private func makePlaybackCapability(
        from playback: (any PlaybackProviding)?
    ) -> (any AudioPlaybackCapability)? {
        guard let playback else { return nil }
        return AudioPlaybackCapabilityAdapter(playback: playback)
    }

    /// 创建并持有音频数据库的 ViewModel 与数据库观察者（幂等）。
    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        // 场景 Provider 必须在 onReady（或运行期 enable）之后解析：此时
        // `ScenePlugin` 已把带持久化的实例注册进内核并恢复了上次场景，得到的
        // 引用才是长期存活、且 `currentScene` 有效的那个。
        // 放在幂等 guard 之前，保证 `onEnable` 重新装配时也会刷新引用。
        sceneBox.scene = kernel.resolveProvider((any SceneProviding).self)

        guard listViewModel == nil else { return }

        guard let playback = kernel.resolveProvider((any PlaybackProviding).self) else { return }
        let list = AudioListViewModel(
            audioLibrary: audioLibraryProvider,
            playbackCapability: makePlaybackCapability(from: playback)
        )
        let root = AudioDBRootViewModel(
            audioLibrary: audioLibraryProvider,
            showDBView: { kernel.resolveProvider((any AppStateProviding).self)?.showDBView() ?? () }
        )
        let db = AudioDBViewModel()
        let observer = AudioDatabaseObserver(
            list: list,
            root: root,
            db: db,
            library: kernel.resolveProvider((any AudioLibraryProviding).self)
        )
        let playbackObserver = AudioDBPlaybackObserver(playback: playback, viewModel: list)

        listViewModel = list
        rootViewModel = root
        dbViewModel = db
        databaseObserver = observer
        self.playbackObserver = playbackObserver

        _ = resolveSceneState()
    }

    @MainActor
    private func teardownState() {
        sceneObserver?.cancel()
        sceneObserver = nil
        sceneState = nil
        databaseObserver?.cancel()
        databaseObserver = nil
        playbackObserver?.cancel()
        playbackObserver = nil
        settingPlaybackObserver?.cancel()
        settingPlaybackObserver = nil
        listViewModel = nil
        rootViewModel = nil
        dbViewModel = nil
    }

    /// 返回当前持有的 ViewModel；若尚未安装（启动前或插件被禁用），
    /// 提供临时空实例保证 View 贡献可用。
    @MainActor
    private func resolveViewModels() -> (list: AudioListViewModel, root: AudioDBRootViewModel, db: AudioDBViewModel) {
        if let listViewModel, let rootViewModel, let dbViewModel {
            return (listViewModel, rootViewModel, dbViewModel)
        }
        let list = AudioListViewModel(
            audioLibrary: audioLibraryProvider,
            playbackCapability: makePlaybackCapability(from: kernel?.resolveProvider((any PlaybackProviding).self))
        )
        let root = AudioDBRootViewModel(audioLibrary: audioLibraryProvider, showDBView: {})
        let db = AudioDBViewModel()
        listViewModel = list
        rootViewModel = root
        dbViewModel = db
        return (list, root, db)
    }

    /// 返回场景门状态（幂等创建）；同时注册场景监听器。
    @MainActor
    private func resolveSceneState() -> AudioDBSceneState {
        if let sceneState { return sceneState }
        // `sceneBox` 为空（onReady 之前被请求）时回落到内核当前场景，避免把一个
        // 永远收不到事件、且初始值恒为 false 的失效状态缓存下来。
        let scene = sceneBox.scene ?? kernel?.resolveProvider((any SceneProviding).self)
        let state = AudioDBSceneState(isMusicScene: scene?.currentScene == .music)
        sceneState = state
        sceneObserver = AudioDBSceneObserver(scene: scene, sceneState: state)
        return state
    }

    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}
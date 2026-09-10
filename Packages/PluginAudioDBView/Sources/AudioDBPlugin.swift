import KernelCore
import ProviderDocsView
import ProviderAudioLibrary
import ProviderPlayback
import ProviderScene
import SwiftUI
import MagicKit
import OSLog

public actor AudioDBViewPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = true

    public static let shared = AudioDBViewPlugin()
    public static let metadata = PluginMetadata(
        displayName: String(localized: String.LocalizationValue(AudioDBPluginInfo.titleKey), bundle: .module),
        description: String(localized: String.LocalizationValue(AudioDBPluginInfo.descriptionKey), bundle: .module),
        iconName: "externaldrive",
        order: 1,
        policy: .alwaysOn,
        category: .library,
    )

    nonisolated(unsafe) private let sceneBox = SceneBox()
    nonisolated(unsafe) private weak var kernel: CisumKernel?
    nonisolated(unsafe) private var listViewModel: AudioListViewModel?
    nonisolated(unsafe) private var rootViewModel: AudioDBRootViewModel?
    nonisolated(unsafe) private var dbViewModel: AudioDBViewModel?
    nonisolated(unsafe) private var databaseObserver: AudioDatabaseObserver?
    nonisolated(unsafe) private var playbackObserver: AudioDBPlaybackObserver?
    nonisolated(unsafe) private var settingPlaybackObserver: AudioDBPlaybackObserver?
    nonisolated(unsafe) private var sceneState: AudioDBSceneState?
    nonisolated(unsafe) private var sceneObserver: AudioDBSceneObserver?

    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioDBPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioDBPluginManualView() })
        }
    }

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
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
    public func onReady(kernel: CisumKernel) async throws {
        installState(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: CisumKernel) async throws {
        self.kernel = kernel
        installState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: CisumKernel) async throws {
        teardownState()
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
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
        let playback = kernel?.playback
        let settingList = AudioListViewModel(
            audioLibrary: audioLibraryProvider,
            playbackCapability: makePlaybackCapability(from: playback)
        )
        let settingTree = AudioTreeViewModel(disk: audioDiskProvider)
        settingPlaybackObserver = AudioDBPlaybackObserver(playback: playback, viewModel: settingList)
        return PluginSettingNavigationItem(
            id: "audiodb",
            title: String(localized: String.LocalizationValue(AudioDBPluginInfo.titleKey), bundle: .module),
            description: Self.metadata.description,
            iconName: Self.metadata.iconName,
            // 设置入口排序不使用 metadata.order（1 是启动优先级），
            // 使用独立值确保「通用」（order=1）排在最前。
            order: 10,
            destination: AnyView(
                AudioDBSettingView()
                    .environmentObject(settingList)
                    .environmentObject(settingTree)
                    .environment(\.audioDBDependencies, settingDependencies)
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
            showDBView: { self.kernel?.appState?.showDBView() ?? () },
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
            self?.kernel?.audioLibrary
        }
    }

    /// 音频磁盘目录闭包：从数据层 Provider 获取。
    @MainActor
    private var audioDiskProvider: @MainActor @Sendable () -> URL? {
        { @MainActor [weak self] in
            self?.kernel?.audioLibrary?.audioDisk
        }
    }

    /// 仓库路径解析诊断（错误视图展示）。
    @MainActor
    private var audioDiagnosticsProvider: @MainActor @Sendable () -> AudioStorageDiagnostics {
        { @MainActor [weak self] in
            AudioStorageDiagnosticsFactory.make(storage: self?.kernel?.storage)
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
    private func installState(kernel: CisumKernel) {
        // 场景 Provider 必须在 onReady（或运行期 enable）之后解析：此时
        // `ScenePlugin` 已把带持久化的实例注册进内核并恢复了上次场景，得到的
        // 引用才是长期存活、且 `currentScene` 有效的那个。
        // 放在幂等 guard 之前，保证 `onEnable` 重新装配时也会刷新引用。
        sceneBox.scene = kernel.resolveProvider((any SceneProviding).self)

        guard listViewModel == nil else { return }

        guard let playback = kernel.playback else { return }
        let list = AudioListViewModel(
            audioLibrary: audioLibraryProvider,
            playbackCapability: makePlaybackCapability(from: playback)
        )
        let root = AudioDBRootViewModel(
            audioLibrary: audioLibraryProvider,
            showDBView: { kernel.appState?.showDBView() ?? () }
        )
        let db = AudioDBViewModel()
        let observer = AudioDatabaseObserver(
            list: list,
            root: root,
            db: db,
            library: kernel.audioLibrary
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
            playbackCapability: makePlaybackCapability(from: kernel?.playback)
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
        let scene = sceneBox.scene ?? kernel?.scene
        let state = AudioDBSceneState(isMusicScene: scene?.currentScene == .music)
        sceneState = state
        sceneObserver = AudioDBSceneObserver(scene: scene, sceneState: state)
        return state
    }

    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}

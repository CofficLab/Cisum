import ProviderAppState
import ProviderAudioLibrary
import ProviderCloudDownload
import ProviderScene
import ProviderDocsView
import ProviderPlayback
import CisumProviderStorage
import ProviderToast
import KernelCore
import ProviderPlugin
import KitAppEvents
import ProviderSettingView
import LumiUI
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
nonisolated(unsafe) private var downloadObserver: CloudDownloadObserver?
    nonisolated(unsafe) private var playbackObserver: AudioDBPlaybackObserver?
    nonisolated(unsafe) private var settingPlaybackObserver: AudioDBPlaybackObserver?
    nonisolated(unsafe) private var sceneState: AudioDBSceneState?
    nonisolated(unsafe) private var sceneObserver: AudioDBSceneObserver?

    /// 本插件消费的能力 Adapter。ViewModel / 依赖结构以 `weak` 或不持有
    /// Adapter，故入口必须显式强持有，否则能力会随装配调用返回而释放。
    /// `library` 内部惰性解析 Provider，因此可跨 boot 阶段长期复用同一实例。
    nonisolated(unsafe) private var library: AudioLibraryCapabilityAdapter?
nonisolated(unsafe) private var download: CloudDownloadCapabilityAdapter?
    nonisolated(unsafe) private var playback: AudioLibraryPlaybackCapabilityAdapter?
    nonisolated(unsafe) private var toast: AudioLibraryToastCapabilityAdapter?
    nonisolated(unsafe) private var sceneCapability: MusicLibrarySceneCapabilityAdapter?
    nonisolated(unsafe) private var settingPlayback: AudioLibraryPlaybackCapabilityAdapter?

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
            contrib.addTabView(ownerPluginID: id) { reason, demoMode in self.addTabView(reason: reason, demoMode: demoMode) }
            if let entry = makeSettingEntry() { kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([entry]) }
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
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: ["audiodb"])
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
                library: makeLibraryCapability(),
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

        // 如果 `installState` 还没被调（典型场景：PluginPlayBack 在 onReady
        // 晚于本插件，而 `installState` 历史上要求 `PlaybackProviding` 立即
        // 就绪，会提前 return，留下 nil listViewModel），则视情节补救：再
        // 跑一次 `installState` 把最小骨架建好，避免落入 `resolveViewModels`
        // 的「临时实例」分支——临时实例没装 `AudioDatabaseObserver`，仓库
        // 同步事件将永远收不到。
        if listViewModel == nil, let kernel {
            installState(kernel: kernel)
        }

        let (list, root, db) = resolveViewModels()
        return (
            AnyView(
                AudioDBPluginTabView(
                    listViewModel: list,
                    rootViewModel: root,
                    dbViewModel: db,
                    library: makeLibraryCapability(),
                    audioDisk: audioDiskProvider,
                    audioDiagnostics: audioDiagnosticsProvider,
                    isImporting: Binding(
                        get: { self.kernel?.resolveProvider((any AppStateProviding).self)?.isImporting ?? false },
                        set: { self.kernel?.resolveProvider((any AppStateProviding).self)?.setImporting($0) }
                    ),
                    showDBView: { self.kernel?.resolveProvider((any AppStateProviding).self)?.showDBView() },
                    demoMode: demoMode
                )
                .appDebugBadge("Music Repository", alignment: .bottomLeading)
            ),
            String(localized: "Music Repository", bundle: .module)
        )
    }

    /// 设置窗口入口：展示音频库文件列表（方式一）与目录树（方式二）。
    @MainActor
    public func makeSettingEntry() -> SettingEntryItem? {
        // 设置页使用独立的 AudioListViewModel，避免与主窗口内容区（AudioList）
        // 共享同一实例——否则设置页 onAppear 触发 handleOnAppear() 重载时，
        // 共享状态变化会传播到主窗口 contentview，导致其闪动。
        let playback = AudioLibraryPlaybackCapabilityAdapter(
            playback: self.kernel?.resolveProvider((any PlaybackProviding).self)
        )
        settingPlayback = playback
        let settingList = AudioListViewModel(
            library: makeLibraryCapability(),
            playback: playback,
            toast: AudioLibraryToastCapabilityAdapter(
                toast: self.kernel?.resolveProvider((any ToastProviding).self)
            )
        )
        let settingTree = AudioTreeViewModel(disk: audioDiskProvider)
        settingPlaybackObserver = AudioDBPlaybackObserver(playback: playback, viewModel: settingList)
        return SettingEntryItem(
            id: "audiodb",
            title: String(localized: String.LocalizationValue(AudioDBPluginInfo.titleKey), bundle: .module),
            systemImage: iconName,
            // 设置入口排序不使用 order（1 是启动优先级），
            // 使用独立值确保「通用」（order=1）排在最前。
            order: 10,
            detail: {
            AudioDBSettingView(
                                viewModel: settingList,
                                treeViewModel: settingTree,
                                dependencies: self.settingDependencies
                            )
        }
        )
    }

    /// 设置页依赖：仓库路径 / 仓库 / 诊断由数据层 Provider 提供。
    @MainActor
    private var settingDependencies: AudioDBDependencies {
        AudioDBDependencies(
                library: makeLibraryCapability(),
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

    /// 组装音频库能力：内部惰性解析内核 Provider，跨 boot 阶段稳定可用。
    @MainActor
    private func makeLibraryCapability() -> AudioLibraryCapabilityAdapter {
        if let library { return library }
        let capability = AudioLibraryCapabilityAdapter { @MainActor [weak self] in
            self?.kernel?.resolveProvider((any AudioLibraryProviding).self)
        }
        library = capability
        return capability
    }

    /// 组装 iCloud 下载进度能力：内部惰性解析内核 Provider。
    ///
    /// 与音频库能力一样持惰性闭包——本插件的视图贡献可能早于 Provider 注册，
    /// 快照引用会让进度能力永久失效。
    @MainActor
    private func makeDownloadCapability() -> CloudDownloadCapabilityAdapter {
        if let download { return download }
        let capability = CloudDownloadCapabilityAdapter { @MainActor [weak self] in
            self?.kernel?.resolveProvider((any CloudDownloadProviding).self)
        }
        download = capability
        return capability
    }

    /// 音频磁盘目录闭包：通过音频库能力读取。
    @MainActor
    private var audioDiskProvider: @MainActor @Sendable () -> URL? {
        { @MainActor [weak self] in
            (self?.library ?? self?.makeLibraryCapability())?.audioDisk
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

    /// 创建并持有音频数据库的 ViewModel 与数据库观察者（幂等）。
    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        // 场景 Provider 必须在 onReady（或运行期 enable）之后解析：此时
        // `ScenePlugin` 已把带持久化的实例注册进内核并恢复了上次场景，得到的
        // 引用才是长期存活、且 `currentScene` 有效的那个。
        // 放在幂等 guard 之前，保证 `onEnable` 重新装配时也会刷新引用。
        sceneBox.scene = kernel.resolveProvider((any SceneProviding).self)

        // 不再在 `onReady` 阶段强依赖 `PlaybackProviding`：播放引擎可能比
        // 本插件晚注册（`PluginPlayBack` 的 `onReady` 可能后跑），但 `addTabView`
        // 视图请求可能在 `PlaybackProviding` 还没就绪时就到达。如果直接 return，
        // 后续 `addTabView` 会通过 `resolveViewModels()` 走「临时实例」分支，
        // 创建的 `AudioListViewModel` 不带 `AudioDatabaseObserver`，
        // 同步事件永远收不到，仓库列表一直空。
        //
        // 因此先建一份仅依赖 `AudioLibraryProviding` 的最小骨架：listViewModel
        // 立刻存在、`AudioDatabaseObserver` 也装上；`PlaybackProviding` 在
        // `onEnable` 阶段被注入时（`installSettingsState` 之类的回调），下次
        // `installState` 重跑会更新 `playback` 字段，listViewModel 的能力
        // 也能补齐。
        if listViewModel == nil {
            let libraryCapability = makeLibraryCapability()
            let playbackCapability = kernel.resolveProvider((any PlaybackProviding).self)
                .map { AudioLibraryPlaybackCapabilityAdapter(playback: $0) }
            let toastCapability = AudioLibraryToastCapabilityAdapter(
                toast: kernel.resolveProvider((any ToastProviding).self)
            )
            playback = playbackCapability
            toast = toastCapability

            let list = AudioListViewModel(
                library: libraryCapability,
                playback: playbackCapability,
                download: makeDownloadCapability(),
                toast: toastCapability
            )
            let root = AudioDBRootViewModel(
                library: libraryCapability,
                showDBView: { kernel.resolveProvider((any AppStateProviding).self)?.showDBView() ?? () }
            )
            let db = AudioDBViewModel()
            let observer = AudioDatabaseObserver(
                list: list,
                root: root,
                db: db,
                library: libraryCapability
            )
            if let playbackCapability {
                playbackObserver = AudioDBPlaybackObserver(playback: playbackCapability, viewModel: list)
            }
            downloadObserver = CloudDownloadObserver(download: makeDownloadCapability(), viewModel: list)

            listViewModel = list
            rootViewModel = root
            dbViewModel = db
            databaseObserver = observer
        }

        // 即便已在 onReady 阶段建好骨架，仍在每次进入时刷新一次播放能力，
        // 让延迟就绪的 `PlaybackProviding` 也能补上。
        if playback == nil, let playbackProvider = kernel.resolveProvider((any PlaybackProviding).self) {
            let capability = AudioLibraryPlaybackCapabilityAdapter(playback: playbackProvider)
            playback = capability
            // listViewModel 还没建好的情况下，`installState` 内的骨架创建会
            // 在下一段（`if listViewModel == nil` 块）里附带上 playbackObserver。
            // 这里只在 listViewModel 已有时补 observer，避免提前创建。
            if let list = listViewModel {
                playbackObserver = AudioDBPlaybackObserver(playback: capability, viewModel: list)
            }
        }

        _ = resolveSceneState()
    }

    @MainActor
    private func teardownState() {
        sceneObserver?.cancel()
        sceneObserver = nil
        sceneCapability = nil
        sceneState = nil
        databaseObserver?.cancel()
        databaseObserver = nil
        downloadObserver?.cancel()
        downloadObserver = nil
        playbackObserver?.cancel()
        playbackObserver = nil
        settingPlaybackObserver?.cancel()
        settingPlaybackObserver = nil
        listViewModel = nil
        rootViewModel = nil
        dbViewModel = nil
        playback = nil
        toast = nil
        settingPlayback = nil
    }

    /// 返回当前持有的 ViewModel；若尚未安装（启动前或插件被禁用），
    /// 提供临时空实例保证 View 贡献可用。
    @MainActor
    private func resolveViewModels() -> (list: AudioListViewModel, root: AudioDBRootViewModel, db: AudioDBViewModel) {
        if let listViewModel, let rootViewModel, let dbViewModel {
            return (listViewModel, rootViewModel, dbViewModel)
        }
        let libraryCapability = makeLibraryCapability()
        let playback = AudioLibraryPlaybackCapabilityAdapter(
            playback: kernel?.resolveProvider((any PlaybackProviding).self)
        )
        self.playback = playback
        let list = AudioListViewModel(
            library: libraryCapability,
            playback: playback,
            toast: AudioLibraryToastCapabilityAdapter(
                toast: kernel?.resolveProvider((any ToastProviding).self)
            )
        )
        let root = AudioDBRootViewModel(library: libraryCapability, showDBView: {})
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
        let capability = MusicLibrarySceneCapabilityAdapter(
            scene: sceneBox.scene ?? kernel?.resolveProvider((any SceneProviding).self)
        )
        sceneCapability = capability
        let state = AudioDBSceneState(isMusicScene: capability.currentScene == .music)
        sceneState = state
        sceneObserver = AudioDBSceneObserver(scene: capability, sceneState: state)
        return state
    }

    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}

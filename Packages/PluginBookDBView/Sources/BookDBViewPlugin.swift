import ProviderScene
import ProviderDocsView
import ProviderPlayback
import ProviderToast
import KernelCore
import ProviderPlugin
import KitAppEvents
import OSLog
import ProviderBook
import ProviderSettingView
import LumiUI
import SwiftUI
import MagicKit

@MainActor
public final class BookDBViewPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: BookDBViewPlugin.self)

    nonisolated static let verbose = false

    public static let shared = BookDBViewPlugin()
    public let order = 12
    public let iconName = BookDBViewPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: BookDBViewPlugin.self),
        name: String(localized: String.LocalizationValue(BookDBViewPluginInfo.titleKey), bundle: .module),
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) private let sceneBox = SceneBox()
    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var gridViewModel: BookGridViewModel?
    nonisolated(unsafe) private var databaseObserver: DBObserver?
    nonisolated(unsafe) private var playbackObserver: PlaybackObserver?

    /// 本插件消费的能力 Adapter。ViewModel / 依赖结构以 `weak` 或不持有
    /// Adapter，故入口必须显式强持有，否则能力会随装配调用返回而释放。
    nonisolated(unsafe) private var bookLibrary: BookLibraryCapabilityAdapter?
    nonisolated(unsafe) private var gridPlayback: BookLibraryPlaybackCapabilityAdapter?
    nonisolated(unsafe) private var gridToast: BookLibraryToastCapabilityAdapter?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if Self.verbose { os_log("\(Self.t)🔌 onRegister") }
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { BookDBViewPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { BookDBViewPluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            contrib.addTabView(ownerPluginID: id) { reason, demoMode in self.addTabView(reason: reason, demoMode: demoMode) }
        }
        if let settings = kernel.resolveProvider((any SettingViewProviding).self),
           let entry = makeSettingEntry() {
            settings.addEntries([entry])
        }
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)🚀 onBoot") }
    }

    /// 所有 Provider 插件完成 onBoot 后再组装依赖它们的 ViewModel 与 Observer。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)🟢 onReady") }
        installState(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)✅ onEnable") }
        installState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)⏹️ onDisable") }
        teardownState()
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: ["bookdb"])
        if Self.verbose { os_log("\(Self.t)🛑 onShutdown") }
        sceneBox.scene = nil
        teardownState()
    }

    @MainActor
    public func addTabView(reason: String, demoMode: Bool = false) -> (view: AnyView, label: String)? {
        guard sceneBox.scene?.currentScene == .audiobooks else { return nil }
        let label = String(localized: String.LocalizationValue(BookDBViewPluginInfo.titleKey), bundle: .module)
        guard kernel?.resolveProvider(BookDatabaseProviding.self) != nil else {
            // os_log(.error, "BookDBViewPlugin failed to resolve database data service")
            let view = BookDBUnavailableView(errorDescription: String(localized: "Storage service is unavailable", bundle: .module))
            return (AnyView(view), label)
        }

        let provider = kernel?.resolveProvider(BookDatabaseProviding.self)
        let dependencies = BookDBViewDependencies(
            dbRoot: databaseRootProvider(),
            bookDisk: bookDiskProvider(),
            bookLibrary: bookLibrary ?? makeBookLibraryCapability(kernel: kernel),
            isDesktop: MagicApp.isDesktop,
            isNotDesktop: MagicApp.isNotDesktop
        )
        let viewModel = resolveViewModel()
        let view = BookDBView(dependencies: dependencies, viewModel: viewModel)
            // .appDebugBadge("Audiobooks Library", alignment: .bottomLeading)
        return (AnyView(view), label)
    }

    /// 设置窗口入口：展示有声书仓库书籍列表（方式一）与目录树（方式二）。
    @MainActor
    public func makeSettingEntry() -> SettingEntryItem? {
        // 设置页使用独立的 BookListViewModel，避免与主窗口内容区（BookGrid）
        // 共享同一实例——否则设置页 onAppear 触发重载时，共享状态变化会传播
        // 到主窗口内容区，导致其闪动。
        let settingList = BookListViewModel(
            bookLibrary: settingDependencies.bookLibrary
        )
        let settingTree = BookTreeViewModel(disk: bookDiskProvider)
        return SettingEntryItem(
            id: "bookdb",
            title: String(localized: String.LocalizationValue(BookDBViewPluginInfo.titleKey), bundle: .module),
            systemImage: iconName,
            order: order,
            detail: {
            BookDBSettingView(
                                viewModel: settingList,
                                treeViewModel: settingTree,
                                dependencies: self.settingDependencies
                            )
        }
        )
    }

    /// 设置页依赖：仓库路径 / 仓库均由数据层 Provider 提供。
    @MainActor
    private var settingDependencies: BookDBDependencies {
        BookDBDependencies(
            bookLibrary: bookLibrary ?? makeBookLibraryCapability(kernel: kernel),
            bookDisk: bookDiskProvider
        )
    }

    // MARK: - State assembly

    // MARK: - Data Provider bridge

    /// 数据库根目录由数据层 Provider 提供。
    @MainActor
    private func databaseRootProvider() -> URL {
        kernel?.resolveProvider(BookDatabaseProviding.self)?.databaseRoot
            ?? FileManager.default.temporaryDirectory
    }

    /// 书籍磁盘目录由数据层 Provider 提供。
    @MainActor
    private var bookDiskProvider: @MainActor @Sendable () -> URL? {
        { @MainActor [weak self] in
            self?.kernel?.resolveProvider(BookDatabaseProviding.self)?.bookDisk
        }
    }

    /// 组装书库能力：把内核 `BookDatabaseProviding` 收窄为本插件的书库能力。
    ///
    /// 数据层插件的 boot 顺序可能晚于本插件的视图贡献请求，此时能力退化为
    /// 「无书库」；`onReady` 的 `installState` 会重新组装并绑定。
    @MainActor
    private func makeBookLibraryCapability(kernel: KernelCoreContainer?) -> BookLibraryCapabilityAdapter {
        BookLibraryCapabilityAdapter(books: kernel?.resolveProvider(BookDatabaseProviding.self))
    }

    @MainActor
    private func installState(kernel: KernelCoreContainer) {
        guard gridViewModel == nil else { return }
        guard let scene = kernel.resolveProvider((any SceneProviding).self) else { return }
        sceneBox.scene = scene
        if Self.verbose { os_log("\(Self.t)🔧 installState") }

        let library = BookLibraryCapabilityAdapter(books: kernel.resolveProvider(BookDatabaseProviding.self))
        let playback = BookLibraryPlaybackCapabilityAdapter(playback: kernel.resolveProvider((any PlaybackProviding).self))
        let toast = BookLibraryToastCapabilityAdapter(toast: kernel.resolveProvider((any ToastProviding).self))
        bookLibrary = library
        gridPlayback = playback
        gridToast = toast

        let viewModel = BookGridViewModel(playback: playback, toast: toast)
        viewModel.bind(library: library)
        let observer = DBObserver(viewModel: viewModel, library: library)
        let playbackObserver = PlaybackObserver(playback: playback, viewModel: viewModel)
        gridViewModel = viewModel
        databaseObserver = observer
        self.playbackObserver = playbackObserver
    }

    @MainActor
    private func teardownState() {
        if Self.verbose { os_log("\(Self.t)🧹 teardownState") }
        databaseObserver?.cancel()
        databaseObserver = nil
        playbackObserver?.cancel()
        playbackObserver = nil
        gridViewModel = nil
        gridPlayback = nil
        gridToast = nil
    }

    @MainActor
    private func resolveViewModel() -> BookGridViewModel {
        if let gridViewModel {
            return gridViewModel
        }
        let playback = BookLibraryPlaybackCapabilityAdapter(playback: kernel?.resolveProvider((any PlaybackProviding).self))
        let toast = BookLibraryToastCapabilityAdapter(toast: kernel?.resolveProvider((any ToastProviding).self))
        gridPlayback = playback
        gridToast = toast
        let viewModel = BookGridViewModel(playback: playback, toast: toast)
        viewModel.bind(library: bookLibrary ?? makeBookLibraryCapability(kernel: kernel))
        gridViewModel = viewModel
        return viewModel
    }

    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}

import KernelCore
import ProviderDocsView
import OSLog
import ProviderBook
import ProviderBook
import ProviderPlayback
import ProviderScene
import SwiftUI
import MagicKit

public actor BookDBViewPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = BookDBViewPlugin()
    public static let metadata = PluginMetadata(
        displayName: String(localized: String.LocalizationValue(BookDBViewPluginInfo.titleKey), bundle: .module),
        description: String(localized: String.LocalizationValue(BookDBViewPluginInfo.descriptionKey), bundle: .module),
        iconName: BookDBViewPluginInfo.iconName,
        order: 12,
        policy: .alwaysOn,
        category: .library,
    )

    nonisolated(unsafe) private let sceneBox = SceneBox()
    nonisolated(unsafe) private weak var kernel: CisumKernel?
    nonisolated(unsafe) private var gridViewModel: BookGridViewModel?
    nonisolated(unsafe) private var databaseObserver: DBObserver?
    nonisolated(unsafe) private var playbackObserver: PlaybackObserver?

    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if Self.verbose { os_log("\(Self.t)🔌 onRegister") }
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { BookDBViewPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { BookDBViewPluginManualView() })
        }
    }

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)🚀 onBoot") }
    }

    /// 所有 Provider 插件完成 onBoot 后再组装依赖它们的 ViewModel 与 Observer。
    @MainActor
    public func onReady(kernel: CisumKernel) async throws {
        if Self.verbose { os_log("\(Self.t)🟢 onReady") }
        installState(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: CisumKernel) async throws {
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)✅ onEnable") }
        installState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: CisumKernel) async throws {
        if Self.verbose { os_log("\(Self.t)⏹️ onDisable") }
        teardownState()
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
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
            bookProvider: provider,
            isDesktop: ConfigShim.isDesktop,
            isNotDesktop: ConfigShim.isNotDesktop
        )
        let viewModel = resolveViewModel()
        let view = BookDBView(dependencies: dependencies, viewModel: viewModel)
        return (AnyView(view), label)
    }

    /// 设置窗口入口：展示有声书仓库书籍列表（方式一）与目录树（方式二）。
    @MainActor
    public func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        // 设置页使用独立的 BookListViewModel，避免与主窗口内容区（BookGrid）
        // 共享同一实例——否则设置页 onAppear 触发重载时，共享状态变化会传播
        // 到主窗口内容区，导致其闪动。
        let settingList = BookListViewModel(
            bookProvider: kernel?.resolveProvider(BookDatabaseProviding.self)
        )
        let settingTree = BookTreeViewModel(disk: bookDiskProvider)
        return PluginSettingNavigationItem(
            id: "bookdb",
            title: String(localized: String.LocalizationValue(BookDBViewPluginInfo.titleKey), bundle: .module),
            description: Self.metadata.description,
            iconName: Self.metadata.iconName,
            order: Self.metadata.order,
            destination: AnyView(
                BookDBSettingView(
                    viewModel: settingList,
                    treeViewModel: settingTree,
                    dependencies: settingDependencies
                )
            )
        )
    }

    /// 设置页依赖：仓库路径 / 仓库均由数据层 Provider 提供。
    @MainActor
    private var settingDependencies: BookDBDependencies {
        BookDBDependencies(
            bookProvider: kernel?.resolveProvider(BookDatabaseProviding.self),
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

    @MainActor
    private func installState(kernel: CisumKernel) {
        guard gridViewModel == nil else { return }

        guard let scene = kernel.resolveProvider((any SceneProviding).self) else { return }
        sceneBox.scene = scene
        if Self.verbose { os_log("\(Self.t)🔧 installState") }

        let viewModel = BookGridViewModel(
            playbackCapability: makePlaybackCapability(from: kernel.playback)
        )
        guard let provider = kernel.resolveProvider(BookDatabaseProviding.self) else { return }
        let observer = DBObserver(viewModel: viewModel, provider: provider)
        let playbackObserver = PlaybackObserver(playback: kernel.playback, viewModel: viewModel)
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
    }

    @MainActor
    private func resolveViewModel() -> BookGridViewModel {
        if let gridViewModel {
            return gridViewModel
        }
        let viewModel = BookGridViewModel(
            playbackCapability: makePlaybackCapability(from: kernel?.playback)
        )
        gridViewModel = viewModel
        return viewModel
    }

    /// 将内核播放 Provider 收窄后注入 ViewModel。
    @MainActor
    private func makePlaybackCapability(
        from playback: (any PlaybackProviding)?
    ) -> (any BookDBPlaybackCapability)? {
        guard let playback else { return nil }
        return BookDBPlaybackCapabilityAdapter(playback: playback)
    }

    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}

private enum ConfigShim {
    static var isDesktop: Bool {
        #if os(macOS)
            true
        #else
            false
        #endif
    }

    static var isNotDesktop: Bool { !isDesktop }
}

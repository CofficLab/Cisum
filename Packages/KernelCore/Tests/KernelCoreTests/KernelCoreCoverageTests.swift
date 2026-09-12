import CisumUIComponents
import Foundation
import ProviderAppState
import ProviderAudioLibrary
import ProviderAudioLike
import ProviderAudioNavigation
import ProviderCloud
import ProviderDevice
import ProviderStorage
import ProviderTheme
import ProviderToast
import SwiftUI
import Testing
@testable import KernelCore

// MARK: - 同步通知捕获

/// selector 观察者在 `NotificationCenter.post` 内同步执行，
/// 适合在 MainActor 测试中确定性捕获事件，无需驱动 runloop。
private final class NotificationCatcher: NSObject {
    var received: Notification?

    @objc
    func handle(_ note: Notification) {
        received = note
    }
}

@MainActor
private func capturedNotification(
    _ name: Notification.Name,
    during post: () -> Void
) -> Notification? {
    let catcher = NotificationCatcher()
    NotificationCenter.default.addObserver(
        catcher,
        selector: #selector(NotificationCatcher.handle(_:)),
        name: name,
        object: nil
    )
    post()
    NotificationCenter.default.removeObserver(catcher)
    return catcher.received
}

private enum TimeoutError: Error {
    case timeout
}

// MARK: - CisumKernelEvent

struct CisumKernelEventTests {
    @Test
    func allCasesHaveUniqueRawValues() {
        let rawValues = CisumKernelEvent.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
        #expect(CisumKernelEvent.allCases.count == 13)
    }

    @Test
    func notificationNameMapsToRawValue() {
        for event in CisumKernelEvent.allCases {
            #expect(event.notificationName == Notification.Name(event.rawValue))
            #expect(event.notificationName.rawValue.hasPrefix("com.coffic.cisum."))
        }
    }

    @Test
    func convenienceNotificationNamesMatchEvents() {
        #expect(Notification.Name.cisumThemeDidChange == CisumKernelEvent.themeDidChange.notificationName)
        #expect(Notification.Name.cisumStorageLocationDidChange == CisumKernelEvent.storageLocationDidChange.notificationName)
        #expect(Notification.Name.cisumStorageLocationDidReset == CisumKernelEvent.storageLocationDidReset.notificationName)
        #expect(Notification.Name.cisumEnabledPluginsDidChange == CisumKernelEvent.enabledPluginsDidChange.notificationName)
        #expect(Notification.Name.cisumPlaybackStateDidChange == CisumKernelEvent.playbackStateDidChange.notificationName)
        #expect(Notification.Name.cisumPlaybackProgressDidUpdate == CisumKernelEvent.playbackProgressDidUpdate.notificationName)
        #expect(Notification.Name.cisumPlaybackAssetDidChange == CisumKernelEvent.playbackAssetDidChange.notificationName)
        #expect(Notification.Name.cisumCloudStatusDidChange == CisumKernelEvent.cloudStatusDidChange.notificationName)
        #expect(Notification.Name.cisumGuideDidComplete == CisumKernelEvent.guideDidComplete.notificationName)
        #expect(Notification.Name.cisumAppLifecycleDidChange == CisumKernelEvent.appLifecycleDidChange.notificationName)
        #expect(Notification.Name.cisumAudioDBSynced == CisumKernelEvent.audioDBSynced.notificationName)
        #expect(Notification.Name.cisumAudioDBUpdated == CisumKernelEvent.audioDBUpdated.notificationName)
        #expect(Notification.Name.cisumSceneDidChange == CisumKernelEvent.sceneDidChange.notificationName)
    }

    @MainActor
    @Test
    func onCisumThemeDidChangeSubscriptionReturnsCancellableToken() {
        // 订阅扩展返回可取消 token；不等待 handler 异步投递。
        let token = NotificationCenter.default.onCisumThemeDidChange {}
        NotificationCenter.default.removeObserver(token)
    }

    @MainActor
    @Test
    func allSubscriptionExtensionsReturnCancellableTokens() {
        let subscriptions: [NSObjectProtocol] = [
            NotificationCenter.default.onCisumThemeDidChange {},
            NotificationCenter.default.onCisumStorageLocationDidChange {},
            NotificationCenter.default.onCisumEnabledPluginsDidChange {},
            NotificationCenter.default.onCisumPlaybackStateDidChange {},
            NotificationCenter.default.onCisumCloudStatusDidChange {},
        ]
        #expect(subscriptions.count == 5)
        for token in subscriptions {
            NotificationCenter.default.removeObserver(token)
        }
    }
}

// MARK: - CisumKernelError

struct CisumKernelErrorTests {
    @Test
    func errorDescriptionsCarryKeyInformation() {
        #expect(CisumKernelError.pluginAlreadyRegistered(id: "a").errorDescription == "Plugin 'a' is already registered")
        #expect(CisumKernelError.pluginNotFound(id: "b").errorDescription == "Plugin 'b' not found")
        #expect(CisumKernelError.pluginNotConfigurable(id: "c").errorDescription == "Plugin 'c' cannot be toggled by user")
        #expect(CisumKernelError.missingRequiredServices(["Storage", "Playback"]).errorDescription == "Missing required services: Storage, Playback")
        #expect(CisumKernelError.serviceNotAvailable(service: "Theme").errorDescription == "Theme service is not available")
        #expect(CisumKernelError.pluginFailed(pluginID: "p", message: "boom").errorDescription == "boom (plugin: p)")
        #expect(CisumKernelError.sceneNotFound(sceneName: "scene").errorDescription == "Scene 'scene' not found")
        #expect(CisumKernelError.pluginIDIsEmpty.errorDescription == "Plugin has an empty ID")
        #expect(CisumKernelError.duplicatePluginID(pluginID: "x", existing: ["x"]).errorDescription == "Duplicate plugin ID: x")
        #expect(CisumKernelError.playbackNotReady.errorDescription == "Playback manager is not ready — no playable asset loaded")
        #expect(CisumKernelError.invalidTheme(themeID: "t").errorDescription == "Invalid or unknown theme: t")
        #expect(CisumKernelError.invalidStoragePath(path: "/x").errorDescription == "Invalid storage path: /x")
    }

    @Test
    func providerAlreadyRegisteredIncludesOwnerWhenKnown() {
        let withOwner = CisumKernelError.providerAlreadyRegistered(
            type: (any ProviderStorage.StorageProviding).self,
            owner: "storage-plugin"
        )
        #expect(withOwner.errorDescription?.contains("by plugin 'storage-plugin'") == true)
        #expect(withOwner.errorDescription?.contains("StorageProviding") == true)

        let noOwner = CisumKernelError.providerAlreadyRegistered(
            type: (any ProviderStorage.StorageProviding).self,
            owner: nil
        )
        #expect(noOwner.errorDescription?.contains("by plugin") == false)
        #expect(noOwner.errorDescription?.hasSuffix("unregister it first") == true)
    }
}

// MARK: - EventManager

@MainActor
struct EventManagerTests {
    private func manager() -> EventManager {
        EventManager()
    }

    @Test
    func postDeliversNotificationWithObjectAndUserInfo() {
        let manager = manager()
        let received = capturedNotification(.cisumAppLifecycleDidChange) {
            manager.postAppLifecycleDidChange(phase: "launched", object: "sender")
        }
        #expect(received?.object as? String == "sender")
        #expect((received?.userInfo?["phase"] as? String) == "launched")
    }

    @Test
    func everyConvenienceMethodPostsItsEvent() {
        let manager = manager()

        let events: [(name: Notification.Name, post: (EventManager) -> Void)] = [
            (.cisumThemeDidChange, { $0.postThemeDidChange() }),
            (.cisumStorageLocationDidChange, { $0.postStorageLocationDidChange() }),
            (.cisumStorageLocationDidReset, { $0.postStorageLocationDidReset() }),
            (.cisumEnabledPluginsDidChange, { $0.postEnabledPluginsDidChange() }),
            (.cisumPlaybackStateDidChange, { $0.postPlaybackStateDidChange() }),
            (.cisumPlaybackProgressDidUpdate, { $0.postPlaybackProgressDidUpdate(progress: 0.5, currentTime: 30) }),
            (.cisumPlaybackAssetDidChange, { $0.postPlaybackAssetDidChange(title: "Song") }),
            (.cisumCloudStatusDidChange, { $0.postCloudStatusDidChange() }),
            (.cisumGuideDidComplete, { $0.postGuideDidComplete() }),
            (.cisumAppLifecycleDidChange, { $0.postAppLifecycleDidChange(phase: "launched") }),
            (.cisumAudioDBSynced, { $0.postAudioDBSynced() }),
            (.cisumAudioDBUpdated, { $0.postAudioDBUpdated() }),
        ]

        for event in events {
            let received = capturedNotification(event.name) {
                event.post(manager)
            }
            #expect(received?.name == event.name)
        }
    }

    @Test
    func playbackStateChangeOmitsUserInfoWhenNil() {
        let manager = manager()
        let received = capturedNotification(.cisumPlaybackStateDidChange) {
            manager.postPlaybackStateDidChange(isPlaying: nil)
        }
        #expect(received?.userInfo == nil)
    }

    @Test
    func playbackStateChangeIncludesIsPlayingWhenProvided() {
        let manager = manager()
        let received = capturedNotification(.cisumPlaybackStateDidChange) {
            manager.postPlaybackStateDidChange(isPlaying: true)
        }
        #expect((received?.userInfo?["isPlaying"] as? Bool) == true)
    }

    @Test
    func postWithVerboseLoggingDoesNotThrow() throws {
        let manager = manager()
        let previous = EventManager.verbose
        EventManager.verbose = true
        defer { EventManager.verbose = previous }
        // verbose 分支仅记录日志，调用不应抛错。
        manager.post(.themeDidChange, object: "sender", userInfo: ["k": 1])
    }
}

// MARK: - 存储假实现

/// 最小存储实现：只用于容器注册/解析往返，方法返回占位值。
@MainActor
private final class TestStorageProvider: ProviderStorage.StorageProviding {
    var currentStorageLocation: ProviderStorage.StorageLocation? { nil }
    var storageRoot: URL? { nil }
    var hasUsableStorageLocation: Bool { false }
    var isICloudStorageAvailable: Bool { false }
    var databaseRoot: URL { URL(fileURLWithPath: "/tmp/test-db") }

    func storageRoot(for location: ProviderStorage.StorageLocation) -> URL? { nil }
    func databaseFile(name: String) throws -> URL {
        URL(fileURLWithPath: "/tmp/test-db/\(name)/\(name).db")
    }

    func pluginDataDirectory(for pluginID: String) -> URL {
        URL(fileURLWithPath: "/tmp/test-db/\(pluginID)")
    }

    func setStorageLocation(_ location: ProviderStorage.StorageLocation?) {}
    func resetStorageLocation() {}
}

// MARK: - 注册面占位实现

/// 以下占位实现仅用于容器注册/解析往返，方法体不会在测试中被调用。
@MainActor
private final class TestAudioLibraryProvider: ProviderAudioLibrary.AudioLibraryProviding {
    var audioDisk: URL? { nil }
    var supportedExtensions: [String] { [] }
    var isAvailable: Bool { false }
    func totalCount() async -> Int { 0 }
    func allURLs(reason: String) async -> [URL] { [] }
    func urls(offset: Int, limit: Int, reason: String) async -> [URL] { [] }
    func contains(_ url: URL) async -> Bool { false }
    func delete(urls: [URL], verbose: Bool) async throws {}
    func sync(urls: [URL], verbose: Bool, isFirst: Bool) async {}
    func sort(url: URL?, reason: String) async {}
    func sortRandom(url: URL?, reason: String, verbose: Bool) async throws {}
}

@MainActor
private final class TestAudioLikeProvider: ProviderAudioLike.AudioLikeProviding {
    func isLiked(url: URL) async -> Bool { false }
    func allLiked() async -> [AudioLikeItem] { [] }
    func updateLikeStatus(audioId: String, liked: Bool, url: URL?, title: String?) async throws {}
}

@MainActor
private final class TestAudioTrackNavigationProvider: ProviderAudioNavigation.AudioTrackNavigationProviding {
    func nextURL(after current: URL?, verbose: Bool) async throws -> URL? { nil }
    func previousURL(before current: URL?, verbose: Bool) async throws -> URL? { nil }
    func firstURL() async throws -> URL? { nil }
    func lastURL() async throws -> URL? { nil }
}

@MainActor
private final class TestCloudProvider: ProviderCloud.CloudProviding {
    var isICloudAvailable: Bool { false }
    var isSignedIn: Bool? { nil }
    var accountStatusDescription: String { "" }
}

@MainActor
private final class TestDeviceProvider: ProviderDevice.DeviceProviding {
    var isMac: Bool { true }
    var isIOS: Bool { false }
    var isPad: Bool { false }
    var deviceModel: String { "test" }
    var systemVersion: String { "1.0" }
    var screenWidth: CGFloat { 100 }
    var screenHeight: CGFloat { 100 }
}

@MainActor
private final class TestToastProvider: ProviderToast.ToastProviding {
    func show(_ toast: CisumToast) {}
    func presentError(title: String, message: String) {}
    func dismissError() {}
    func showLoading(title: String, detail: String?) {}
    func dismissLoading() {}
    func dismissAll() {}
}

// MARK: - 服务注册/解析便捷面

@MainActor
struct KernelServiceSurfaceTests {
    @Test
    func unregisteredAccessorsReturnNil() {
        let kernel = CisumKernelContainer()
        #expect(kernel.audioLibrary == nil)
        #expect(kernel.audioLike == nil)
        #expect(kernel.audioTrackNavigation == nil)
        #expect(kernel.storage == nil)
        #expect(kernel.playback == nil)
        #expect(kernel.plugin == nil)
        #expect(kernel.theme == nil)
        #expect(kernel.cloud == nil)
        #expect(kernel.appState == nil)
        #expect(kernel.device == nil)
        #expect(kernel.toast == nil)
    }

    @Test
    func convenienceRegistrationResolvesSameInstance() throws {
        let kernel = CisumKernelContainer()

        let appState = BasicAppStateService()
        try kernel.registerAppStateService(appState)
        #expect((kernel.appState as AnyObject?) === appState)

        let storage = TestStorageProvider()
        try kernel.registerStorage(storage)
        #expect((kernel.storage as AnyObject?) === storage)
    }

    @Test
    func allConvenienceRegistrationsResolve() async throws {
        let kernel = CisumKernelContainer()

        let audioLibrary = TestAudioLibraryProvider()
        try kernel.registerAudioLibrary(audioLibrary)
        #expect((kernel.audioLibrary as AnyObject?) === audioLibrary)

        let audioLike = TestAudioLikeProvider()
        try kernel.registerAudioLike(audioLike)
        #expect((kernel.audioLike as AnyObject?) === audioLike)

        let navigation = TestAudioTrackNavigationProvider()
        try kernel.registerAudioTrackNavigation(navigation)
        #expect((kernel.audioTrackNavigation as AnyObject?) === navigation)

        let cloud = TestCloudProvider()
        try kernel.registerCloudService(cloud)
        #expect((kernel.cloud as AnyObject?) === cloud)

        let device = TestDeviceProvider()
        try kernel.registerDeviceService(device)
        #expect((kernel.device as AnyObject?) === device)

        let toast = TestToastProvider()
        try kernel.registerToastService(toast)
        #expect((kernel.toast as AnyObject?) === toast)

        // Plugin 服务用真实贡献服务注册。
        let contributionService = PluginContributionService(manager: kernel.pluginManager)
        try kernel.registerPluginService(contributionService)
        #expect((kernel.plugin as AnyObject?) === contributionService)
    }

    @Test
    func themeServiceRegistersViaConvenienceMethod() throws {
        let kernel = CisumKernelContainer()
        let theme = ThemeService(registry: LumiUIThemeRegistry()) { [] }
        try kernel.registerThemeService(theme)
        #expect((kernel.theme as AnyObject?) === theme)
    }

    @Test
    func duplicateConvenienceRegistrationThrows() throws {
        let kernel = CisumKernelContainer()
        try kernel.registerStorage(TestStorageProvider())
        #expect(throws: CisumKernelError.self) {
            try kernel.registerStorage(TestStorageProvider())
        }
    }

    @Test
    func startupThrowsWhenRequiredServicesMissing() async throws {
        let kernel = CisumKernelContainer()
        // 未注册任何服务：startup 必须因 Storage/Playback/Plugin/Theme 缺失而失败。
        do {
            try await kernel.startup()
            Issue.record("Expected missingRequiredServices")
        } catch let error as CisumKernelError {
            guard case let .missingRequiredServices(services) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(services.contains("Storage"))
            #expect(services.contains("Playback"))
            #expect(services.contains("Plugin"))
            #expect(services.contains("Theme"))
        }
    }
}

// MARK: - 测试用 Chrome 主题

/// 可指定 identifier 的迷你 chrome 主题，用于构造多主题贡献。
private struct TestChromeTheme: LumiAppChromeTheme {
    let identifier: String
    let appearanceKind: ThemeAppearanceKind
    let displayName: String
    let compactName: String
    let description: String
    let iconName: String
    let iconColor: Color

    init(identifier: String, appearanceKind: ThemeAppearanceKind = .system, displayName: String = "") {
        self.identifier = identifier
        self.appearanceKind = appearanceKind
        self.displayName = displayName
        self.compactName = displayName
        self.description = ""
        self.iconName = "paintpalette"
        self.iconColor = Color.accentColor
    }

    func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (Color.blue, Color.green, Color.orange)
    }

    func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (Color.black, Color.gray, Color.white)
    }

    func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
        (Color.blue.opacity(0.1), Color.blue.opacity(0.2), Color.blue.opacity(0.3))
    }
}

private func makeContribution(
    id: String,
    pluginOrder: Int,
    appearanceKind: ThemeAppearanceKind = .system
) -> LumiUIThemeContribution {
    LumiUIThemeContribution(
        sortKey: ThemeSortKey(pluginOrder: pluginOrder, themeId: id),
        chromeTheme: TestChromeTheme(identifier: id, appearanceKind: appearanceKind, displayName: id),
        editorThemeId: id
    )
}

// MARK: - 贡献探针插件

/// 低 order 贡献插件：提供各类 UI 贡献。
actor ContributionProbeA: SuperPlugin {
    nonisolated static let shared = ContributionProbeA()
    nonisolated static var metadata: PluginMetadata {
        PluginMetadata(
            id: "probe-a",
            displayName: "Probe A",
            description: "",
            order: 1,
            policy: .alwaysOn
        )
    }

    nonisolated var id: String { "probe-a" }

    @MainActor
    func addStatusView() -> AnyView? { AnyView(Text("status-a")) }
    @MainActor
    func addStateView() -> AnyView? { AnyView(Text("state-a")) }
    @MainActor
    func addPosterView() -> AnyView? { AnyView(Text("poster-a")) }
    @MainActor
    func addSettingView() -> AnyView? { AnyView(Text("setting-a")) }
    @MainActor
    func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        PluginSettingNavigationItem(
            id: "nav-a",
            title: "Nav A",
            iconName: "gearshape",
            order: 2,
            destination: AnyView(Text("dest-a"))
        )
    }
    @MainActor
    func addToolBarButtons() -> [(id: String, view: AnyView)] {
        [("tool-a", AnyView(Text("tool-a")))]
    }
    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [makeContribution(id: "theme-a", pluginOrder: 1)]
    }
    @MainActor
    func addTabView(reason: String, demoMode: Bool) -> (view: AnyView, label: String)? {
        (AnyView(Text("tab-a:\(reason):\(demoMode)")), "tab-a")
    }
    @MainActor
    func addGuideView() -> AnyView? { AnyView(Text("guide-a")) }
    @MainActor
    func addHeroView() -> AnyView? { AnyView(Text("hero-a")) }
    @MainActor
    func addRightAlbumView() -> AnyView? { AnyView(Text("album-a")) }
    @MainActor
    func addControlButtonsView() -> AnyView? { AnyView(Text("buttons-a")) }
    @MainActor
    func addProgressView() -> AnyView? { AnyView(Text("progress-a")) }
}

/// 高 order 贡献插件：用于聚合排序与单槽位“取首个”验证。
actor ContributionProbeB: SuperPlugin {
    nonisolated static let shared = ContributionProbeB()
    nonisolated static var metadata: PluginMetadata {
        PluginMetadata(
            id: "probe-b",
            displayName: "Probe B",
            description: "",
            order: 2,
            policy: .alwaysOn
        )
    }

    nonisolated var id: String { "probe-b" }

    @MainActor
    func addStatusView() -> AnyView? { AnyView(Text("status-b")) }
    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        // 贡献不同主题 id：用于验证按插件 order 排序后聚合顺序。
        [makeContribution(id: "theme-b", pluginOrder: 2)]
    }
    @MainActor
    func addHeroView() -> AnyView? { AnyView(Text("hero-b")) }
}

// MARK: - PluginContributionService

@MainActor
struct PluginContributionServiceTests {
    private func makeService(plugins: [any SuperPlugin]) -> (CisumKernelContainer, BuiltinPluginManager, PluginContributionService) {
        let kernel = CisumKernelContainer()
        kernel.pluginManager.initializePlugins(plugins)
        let service = PluginContributionService(manager: kernel.pluginManager)
        return (kernel, kernel.pluginManager, service)
    }

    @Test
    func allPluginsExposesManagerRegistry() {
        let (_, _, service) = makeService(plugins: [ContributionProbeA(), ContributionProbeB()])
        #expect(service.allPlugins.count == 2)
    }

    @Test
    func collectionViewsAggregateAndCache() {
        let (_, _, service) = makeService(plugins: [ContributionProbeA(), ContributionProbeB()])

        let statusViews = service.getStatusViews()
        #expect(statusViews.count == 2)

        let stateViews = service.getStateViews()
        #expect(stateViews.count == 1)
        let posterViews = service.getPosterViews()
        #expect(posterViews.count == 1)
        let settingViews = service.getSettingViews()
        #expect(settingViews.count == 1)

        // 缓存：第二次调用返回同一批视图且不重复收集。
        #expect(service.getStatusViews().count == 2)
    }

    @Test
    func settingNavigationItemsSortedByOrder() {
        let (_, _, service) = makeService(plugins: [ContributionProbeA(), ContributionProbeB()])
        let items = service.getSettingNavigationItems()
        #expect(items.count == 1)
        #expect(items.first?.id == "nav-a")
        #expect(items.first?.order == 2)
    }

    @Test
    func tabViewsPassThroughReasonAndDemoMode() {
        let (_, _, service) = makeService(plugins: [ContributionProbeA(), ContributionProbeB()])
        let tabs = service.getTabViews(reason: "ContentView", demoMode: true)
        #expect(tabs.count == 1)
        #expect(tabs.first?.label == "tab-a")
    }

    @Test
    func toolBarButtonsAggregate() {
        let (_, _, service) = makeService(plugins: [ContributionProbeA(), ContributionProbeB()])
        let buttons = service.getToolBarButtons()
        #expect(buttons.count == 1)
        #expect(buttons.first?.id == "tool-a")
    }

    @Test
    func themeContributionsSortedByPluginOrderAndRewriteSortKey() {
        let (_, _, service) = makeService(plugins: [ContributionProbeA(), ContributionProbeB()])
        let themes = service.getThemeContributions()
        // A(order 1) 贡献 theme-a，B(order 2) 贡献 theme-b；排序后 A 在前。
        #expect(themes.count == 2)
        #expect(themes[0].id == "theme-a")
        #expect(themes[0].sortKey.pluginOrder == 1)
        #expect(themes[1].id == "theme-b")
        #expect(themes[1].sortKey.pluginOrder == 2)
    }

    @Test
    func themeContributionsDeduplicateByIdKeepingFirstSortedPlugin() {
        // 两个插件贡献相同 id 的主题：排序后 order 1 的插件先插入，去重应保留它。
        actor DuplicateThemeA: SuperPlugin {
            nonisolated static let shared = DuplicateThemeA()
            nonisolated static var metadata: PluginMetadata {
                PluginMetadata(id: "dup-a", displayName: "Dup A", description: "", order: 1, policy: .alwaysOn)
            }
            nonisolated var id: String { "dup-a" }
            @MainActor
            func addThemeContributions() -> [LumiUIThemeContribution] {
                [makeContribution(id: "shared-theme", pluginOrder: 1)]
            }
        }
        actor DuplicateThemeB: SuperPlugin {
            nonisolated static let shared = DuplicateThemeB()
            nonisolated static var metadata: PluginMetadata {
                PluginMetadata(id: "dup-b", displayName: "Dup B", description: "", order: 2, policy: .alwaysOn)
            }
            nonisolated var id: String { "dup-b" }
            @MainActor
            func addThemeContributions() -> [LumiUIThemeContribution] {
                [makeContribution(id: "shared-theme", pluginOrder: 2)]
            }
        }

        let (_, _, service) = makeService(plugins: [DuplicateThemeB(), DuplicateThemeA()])
        let themes = service.getThemeContributions()
        #expect(themes.count == 1)
        #expect(themes.first?.sortKey.pluginOrder == 1)
    }

    @Test
    func singleSlotViewsPickFirstPlugin() {
        let (_, _, service) = makeService(plugins: [ContributionProbeA(), ContributionProbeB()])
        // 单槽位取首个启用插件：A 提供 hero，B 也提供但不应被使用。
        #expect(service.getHeroView() != nil)
        #expect(service.getRightAlbumView() != nil)
        #expect(service.getControlButtonsView() != nil)
        #expect(service.getProgressView() != nil)
        #expect(service.getGuideView() != nil)
    }

    @Test
    func invalidateCachesRefreshesCollections() {
        let (_, _, service) = makeService(plugins: [ContributionProbeA(), ContributionProbeB()])
        _ = service.getStatusViews()
        _ = service.getThemeContributions()

        // 失效后再次读取仍可正常聚合（缓存被清空后重新收集）。
        service.invalidateCaches()
        #expect(service.getStatusViews().count == 2)
        #expect(service.getThemeContributions().count == 2)
    }

    @Test
    func invalidateCachesNotifiesObservers() {
        let (_, _, service) = makeService(plugins: [ContributionProbeA()])
        var events: [PluginProvidingEvent] = []
        let handle = service.addObserver { events.append($0) }

        service.invalidateCaches()
        #expect(events.count == 1)
        if case .contributionsChanged = events[0] {
            // 期望事件类型
        } else {
            Issue.record("Expected contributionsChanged")
        }

        handle.cancel()
        service.invalidateCaches()
        #expect(events.count == 1)
    }
}

// MARK: - ThemeService

@MainActor
struct ThemeServiceTests {
    private static let selectedThemeKey = "Cisum.SelectedThemeID"

    private func makeService(contributions: [LumiUIThemeContribution]) -> (ThemeService, LumiUIThemeRegistry) {
        let registry = LumiUIThemeRegistry()
        let service = ThemeService(registry: registry) { contributions }
        return (service, registry)
    }

    @Test
    func reloadThemesFallsBackToFirstWhenNothingSaved() {
        UserDefaults.standard.removeObject(forKey: Self.selectedThemeKey)
        let (service, _) = makeService(contributions: [
            makeContribution(id: "theme-a", pluginOrder: 1),
            makeContribution(id: "theme-b", pluginOrder: 2),
        ])
        service.reloadThemes()
        #expect(service.allThemeContributions.count == 2)
        #expect(service.selectedThemeID == "theme-a")
    }

    @Test
    func reloadThemesRestoresSavedSelectionWhenValid() {
        UserDefaults.standard.set("theme-b", forKey: Self.selectedThemeKey)
        let (service, _) = makeService(contributions: [
            makeContribution(id: "theme-a", pluginOrder: 1),
            makeContribution(id: "theme-b", pluginOrder: 2),
        ])
        service.reloadThemes()
        #expect(service.selectedThemeID == "theme-b")
    }

    @Test
    func reloadThemesClearsSelectionWhenContributionsEmpty() {
        UserDefaults.standard.removeObject(forKey: Self.selectedThemeKey)
        let (service, _) = makeService(contributions: [])
        service.reloadThemes()
        #expect(service.allThemeContributions.isEmpty)
        #expect(service.selectedThemeID == "")
    }

    @Test
    func selectThemePersistsAndSyncs() {
        UserDefaults.standard.removeObject(forKey: Self.selectedThemeKey)
        let (service, _) = makeService(contributions: [
            makeContribution(id: "theme-a", pluginOrder: 1),
            makeContribution(id: "theme-b", pluginOrder: 2),
        ])
        service.reloadThemes()
        #expect(service.selectedThemeID == "theme-a")

        service.selectTheme("theme-b")
        #expect(service.selectedThemeID == "theme-b")
        #expect(UserDefaults.standard.string(forKey: Self.selectedThemeKey) == "theme-b")
    }

    @Test
    func selectThemeIgnoresUnknownAndDuplicate() {
        UserDefaults.standard.removeObject(forKey: Self.selectedThemeKey)

        // unknown 分支：空贡献列表下任何选择都应被忽略。
        let emptyService = makeService(contributions: []).0
        emptyService.reloadThemes()
        emptyService.selectTheme("not-a-theme")
        #expect(emptyService.selectedThemeID == "")

        // duplicate 分支：重复选择相同主题不应重复同步。
        let (service, _) = makeService(contributions: [makeContribution(id: "theme-a", pluginOrder: 1)])
        service.reloadThemes()
        service.selectTheme("theme-a")
        service.selectTheme("theme-a")
        #expect(service.selectedThemeID == "theme-a")
    }

    @Test
    func preferredColorSchemeFollowsChromeAppearance() {
        UserDefaults.standard.removeObject(forKey: Self.selectedThemeKey)

        let dark = makeService(contributions: [makeContribution(id: "dark", pluginOrder: 1, appearanceKind: .dark)]).0
        dark.reloadThemes()
        #expect(dark.preferredColorScheme == .dark)

        let light = makeService(contributions: [makeContribution(id: "light", pluginOrder: 1, appearanceKind: .light)]).0
        light.reloadThemes()
        #expect(light.preferredColorScheme == .light)

        let system = makeService(contributions: [makeContribution(id: "system", pluginOrder: 1, appearanceKind: .system)]).0
        system.reloadThemes()
        #expect(system.preferredColorScheme == nil)
    }

    @Test
    func observerReceivesReloadAndSelectionEvents() {
        UserDefaults.standard.removeObject(forKey: Self.selectedThemeKey)
        let (service, _) = makeService(contributions: [
            makeContribution(id: "theme-a", pluginOrder: 1),
            makeContribution(id: "theme-b", pluginOrder: 2),
        ])
        var events: [String] = []
        let handle = service.addObserver { event in
            switch event {
            case .themesChanged(let themes):
                events.append("themes:\(themes.count)")
            case .selectionChanged(let id):
                events.append("selected:\(id)")
            }
        }

        service.reloadThemes()
        #expect(events.contains("themes:2"))
        #expect(events.contains("selected:theme-a"))

        service.selectTheme("theme-b")
        #expect(events.filter { $0.hasPrefix("selected:") }.count == 2)

        handle.cancel()
        service.reloadThemes()
        #expect(events.count == 3)
    }
}

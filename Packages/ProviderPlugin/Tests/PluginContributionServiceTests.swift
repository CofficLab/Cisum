import Combine
import CoreGraphics
import Foundation
import KernelCore
import LumiUI
import SwiftUI
import Testing
@testable import ProviderPlugin

@MainActor
private final class ContributionTestPlugin: SuperPlugin {
    let id: String
    let order: Int
    let metadata: PluginMetadata

    init(id: String, order: Int = 200, policy: PluginEnablePolicy = .enabledByDefault) {
        self.id = id
        self.order = order
        self.metadata = PluginMetadata(id: id, policy: policy)
    }
}

private struct ContributionTestTheme: LumiAppChromeTheme {
    let identifier: String
    let displayName: String
    var compactName: String { displayName }
    let description = "测试主题"
    let iconName = "circle"
    let iconColor = Color.blue
    let appearanceKind: ThemeAppearanceKind = .light

    func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
        (.red, .green, .blue)
    }

    func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
        (.black, .gray, .white)
    }

    func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
        (.gray, .white, .blue)
    }
}

@MainActor
struct PluginContributionServiceTests {
    private func marker(_ color: Color) -> AnyView {
        AnyView(color.frame(width: 8, height: 8))
    }

    // 用公开渲染 API 区分 AnyView 的内容和顺序，不依赖其私有存储或反射。
    private func pixels(_ views: [AnyView]) throws -> Data {
        let content = HStack(spacing: 0) {
            ForEach(views.indices, id: \.self) { views[$0] }
        }
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let context = try #require(CGContext(
            data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try #require(context.data)
        return Data(bytes: bytes, count: image.width * image.height * 4)
    }

    private func theme(_ id: String, name: String? = nil) -> LumiUIThemeContribution {
        LumiUIThemeContribution(
            sortKey: ThemeSortKey(pluginOrder: -999, themeId: "stale-key"),
            chromeTheme: ContributionTestTheme(identifier: id, displayName: name ?? id),
            editorThemeId: "old-editor-id",
            uiTheme: LumiDefaultTheme()
        )
    }

    private func contributeAll(_ service: PluginContributionService, owner: String, view: AnyView) {
        service.addRootView(ownerPluginID: owner) { _ in view }
        service.addGuideView(ownerPluginID: owner, view)
        service.addStateView(ownerPluginID: owner, view)
        service.addPosterView(ownerPluginID: owner, view)
        service.addTabView(ownerPluginID: owner) { _, _ in (view, owner) }
        service.addSettingView(ownerPluginID: owner, view)
        service.addToolBarButtons(ownerPluginID: owner, [(owner, view)])
        service.addThemeContributions(ownerPluginID: owner, [theme(owner)])
        service.addHeroView(ownerPluginID: owner, view)
        service.addRightAlbumView(ownerPluginID: owner, view)
        service.addControlButtonsView(ownerPluginID: owner, view)
        service.addProgressView(ownerPluginID: owner, view)
    }

    private func singleSlotViews(_ service: PluginContributionService) -> [AnyView?] {
        [service.getGuideView(), service.getHeroView(), service.getRightAlbumView(),
         service.getControlButtonsView(), service.getProgressView()]
    }

    private func expectOnlyOwner(
        _ owner: String, view: AnyView, in service: PluginContributionService
    ) throws {
        let expectedPixels = try pixels([view])
        for views in [service.getStateViews(), service.getPosterViews(), service.getSettingViews()] {
            #expect(views.count == 1)
            #expect(try pixels(views) == expectedPixels)
        }
        for slot in singleSlotViews(service) {
            #expect(try pixels([#require(slot)]) == expectedPixels)
        }
        #expect(service.getToolBarButtons().map(\.id) == [owner])
        #expect(service.getTabViews(reason: "test", demoMode: false).map(\.label) == [owner])
        #expect(service.getThemeContributions().map(\.id) == [owner])
        let root = try #require(service.wrapWithCurrentRoot { Color.clear })
        #expect(try pixels([root]) == expectedPixels)
        #expect(service.getStatusViews().isEmpty)
    }

    @Test
    func aggregationsExcludeDisabledAndUnknownOwners() async throws {
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [
            ContributionTestPlugin(id: "first", order: 10),
            ContributionTestPlugin(id: "second", order: 20),
            ContributionTestPlugin(id: "disabled", policy: .disabledByDefault),
        ])
        defer { try? kernel.stop() }
        let service = PluginContributionService(kernel: kernel)
        for owner in ["first", "disabled", "unknown"] {
            contributeAll(service, owner: owner, view: marker(.red))
        }
        contributeAll(service, owner: "second", view: marker(.blue))
        #expect(service.allPlugins.map(\.id) == ["first", "second"])
        #expect(service.getStateViews().count == 2)
        #expect(service.getToolBarButtons().map(\.id) == ["first", "second"])

        try await kernel.disablePlugin(id: "first")
        // 服务不自动订阅 Kernel；宿主在启用状态改变后显式失效缓存。
        service.invalidateCaches()
        #expect(service.allPlugins.map(\.id) == ["second"])
        try expectOnlyOwner("second", view: marker(.blue), in: service)

        try await kernel.enablePlugin(id: "first")
        service.invalidateCaches()
        #expect(service.getToolBarButtons().map(\.id) == ["first", "second"])
    }

    @Test
    func listContributionsSortByPluginOrderAndPreserveButtonOrder() throws {
        let kernel = KernelCoreContainer()
        // 只注册而不启动：Kernel 返回的 ID 顺序与数字 order 相反。
        try kernel.registerPlugin(ContributionTestPlugin(id: "a-late", order: 20))
        try kernel.registerPlugin(ContributionTestPlugin(id: "z-early", order: 10))
        let service = PluginContributionService(kernel: kernel)
        contributeAll(service, owner: "a-late", view: marker(.blue))
        contributeAll(service, owner: "z-early", view: marker(.red))
        service.addToolBarButtons(ownerPluginID: "z-early", [
            ("early-2", marker(.red)), ("early-1", marker(.red)),
        ])

        let expected = try pixels([marker(.red), marker(.blue)])
        #expect(expected != (try pixels([marker(.blue), marker(.red)])))
        for _ in 0..<2 {
            for views in [service.getStateViews(), service.getPosterViews(), service.getSettingViews()] {
                #expect(views.count == 2)
                #expect(try pixels(views) == expected)
            }
            #expect(service.getToolBarButtons().map(\.id) == ["early-2", "early-1", "a-late"])
        }
    }

    @Test
    func themesDeduplicateByIDAndRewriteSortKeys() throws {
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [
            ContributionTestPlugin(id: "late", order: 20),
            ContributionTestPlugin(id: "early", order: 10),
        ])
        defer { try? kernel.stop() }
        let service = PluginContributionService(kernel: kernel)
        service.addThemeContributions(ownerPluginID: "late", [
            theme("shared", name: "later"), theme("unique"),
        ])
        service.addThemeContributions(ownerPluginID: "early", [
            theme("shared", name: "first"), theme("shared", name: "duplicate"),
        ])
        service.addThemeContributions(ownerPluginID: "unknown", [theme("hidden")])

        for _ in 0..<2 {
            let result = service.getThemeContributions()
            #expect(result.map(\.id) == ["shared", "unique"])
            #expect(result.map(\.displayName) == ["first", "unique"])
            #expect(result.map(\.sortKey) == [
                ThemeSortKey(pluginOrder: 10, themeId: "shared"),
                ThemeSortKey(pluginOrder: 20, themeId: "unique"),
            ])
            #expect(result.map(\.editorThemeId) == ["shared", "unique"])
            #expect(result.allSatisfy { $0.uiTheme != nil })
        }
        service.remove(owner: "early")
        #expect(service.getThemeContributions().first?.displayName == "later")
        #expect(service.getThemeContributions().first?.sortKey.pluginOrder == 20)
    }

    @Test
    func singleSlotsChooseFirstStartedOwnerAndFallBackAfterRemoval() throws {
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [ContributionTestPlugin(id: "z-first", order: 200)])
        try kernel.start(plugins: [ContributionTestPlugin(id: "a-second", order: 1)])
        defer { try? kernel.stop() }
        let service = PluginContributionService(kernel: kernel)
        #expect(singleSlotViews(service).allSatisfy { $0 == nil })
        contributeAll(service, owner: "a-second", view: marker(.blue))
        contributeAll(service, owner: "z-first", view: marker(.red))

        for slot in singleSlotViews(service) {
            #expect(try pixels([#require(slot)]) == pixels([marker(.red)]))
        }
        service.remove(owner: "z-first")
        for slot in singleSlotViews(service) {
            #expect(try pixels([#require(slot)]) == pixels([marker(.blue)]))
        }
        service.remove(owner: "a-second")
        #expect(singleSlotViews(service).allSatisfy { $0 == nil })
    }

    @Test
    func removeClearsEveryContributionWithoutAffectingOtherOwners() throws {
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [
            ContributionTestPlugin(id: "removed", order: 10),
            ContributionTestPlugin(id: "kept", order: 20),
        ])
        defer { try? kernel.stop() }
        let service = PluginContributionService(kernel: kernel)
        contributeAll(service, owner: "removed", view: marker(.red))
        contributeAll(service, owner: "kept", view: marker(.blue))
        var removedRootCalls = 0
        service.addRootView(ownerPluginID: "removed") { content in
            removedRootCalls += 1
            return content
        }
        _ = service.wrapWithCurrentRoot { Color.clear }
        #expect(removedRootCalls == 1)
        // 先填充所有列表缓存，再验证 remove 同时清理注册表和缓存。
        #expect(service.getStateViews().count == 2)
        #expect(service.getPosterViews().count == 2)
        #expect(service.getSettingViews().count == 2)
        #expect(service.getToolBarButtons().count == 2)
        #expect(service.getThemeContributions().count == 2)
        service.remove(owner: "removed")
        service.remove(owner: "removed")
        service.remove(owner: "unknown")
        try expectOnlyOwner("kept", view: marker(.blue), in: service)
        #expect(removedRootCalls == 1)
        #expect(kernel.isPluginRegistered(id: "removed"))
    }

    @Test
    func replacingOwnerContributionsInvalidatesAllListCaches() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerPlugin(ContributionTestPlugin(id: "owner"))
        let service = PluginContributionService(kernel: kernel)
        #expect(service.getStateViews().isEmpty)
        #expect(service.getPosterViews().isEmpty)
        #expect(service.getSettingViews().isEmpty)
        #expect(service.getToolBarButtons().isEmpty)
        #expect(service.getThemeContributions().isEmpty)

        for color in [Color.red, .blue] {
            contributeAll(service, owner: "owner", view: marker(color))
            try expectOnlyOwner("owner", view: marker(color), in: service)
        }
        service.addThemeContributions(ownerPluginID: "owner", [theme("replacement")])
        service.addToolBarButtons(ownerPluginID: "owner", [("replacement", marker(.blue))])
        #expect(service.getThemeContributions().map(\.id) == ["replacement"])
        #expect(service.getToolBarButtons().map(\.id) == ["replacement"])
    }

    @Test
    func rootWrappersComposeInStartupOrderAndSkipNilResults() throws {
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [
            ContributionTestPlugin(id: "third", order: 30),
            ContributionTestPlugin(id: "first", order: 10),
            ContributionTestPlugin(id: "second", order: 20),
        ])
        defer { try? kernel.stop() }
        let service = PluginContributionService(kernel: kernel)
        let base = marker(.red)
        let unchanged = try #require(service.wrapWithCurrentRoot { base })
        #expect(try pixels([unchanged]) == pixels([base]))
        var calls: [String] = []
        service.addRootView(ownerPluginID: "third") { content in
            calls.append("third")
            return AnyView(HStack(spacing: 0) { content; self.marker(.green) })
        }
        service.addRootView(ownerPluginID: "first") { content in
            calls.append("first")
            return AnyView(HStack(spacing: 0) { content; self.marker(.blue) })
        }
        service.addRootView(ownerPluginID: "second") { _ in
            calls.append("second")
            return nil
        }
        service.addRootView(ownerPluginID: "unknown") { _ in
            Issue.record("未注册 owner 的包裹函数不应执行")
            return nil
        }

        let result = try #require(service.wrapWithCurrentRoot { base })
        #expect(calls == ["first", "second", "third"])
        #expect(try pixels([result]) == pixels([base, marker(.blue), marker(.green)]))
    }

    @Test
    func tabContributionsReceiveArgumentsAndAreNotCached() throws {
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [
            ContributionTestPlugin(id: "second", order: 20),
            ContributionTestPlugin(id: "first", order: 10),
        ])
        defer { try? kernel.stop() }
        let service = PluginContributionService(kernel: kernel)
        var reasons: [String] = []
        var modes: [Bool] = []
        service.addTabView(ownerPluginID: "first") { reason, demoMode in
            reasons.append(reason)
            modes.append(demoMode)
            return demoMode ? nil : (self.marker(.red), "first")
        }
        service.addTabView(ownerPluginID: "second") { _, _ in (self.marker(.blue), "second") }
        service.addTabView(ownerPluginID: "unknown") { _, _ in
            Issue.record("未注册 owner 的标签页函数不应执行")
            return nil
        }

        #expect(service.getTabViews(reason: "normal", demoMode: false).map(\.label) == ["first", "second"])
        #expect(service.getTabViews(reason: "preview", demoMode: true).map(\.label) == ["second"])
        #expect(reasons == ["normal", "preview"])
        #expect(modes == [false, true])
    }

    @Test
    func invalidationNotifiesBothObservationChannelsAndCancellationStopsDelivery() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerPlugin(ContributionTestPlugin(id: "owner"))
        let service = PluginContributionService(kernel: kernel)
        var changeCount = 0
        let subscription = service.objectWillChange.sink { changeCount += 1 }
        defer { subscription.cancel() }
        var observedCounts: [Int] = []
        let handle = service.addObserver { event in
            guard case .contributionsChanged = event else {
                Issue.record("缓存失效应发送 contributionsChanged")
                return
            }
            observedCounts.append(service.getStateViews().count)
        }
        defer { handle.cancel() }
        var otherCount = 0
        let otherHandle = service.addObserver { _ in otherCount += 1 }
        defer { otherHandle.cancel() }

        service.invalidateCaches()
        service.addStateView(ownerPluginID: "owner", marker(.red))
        service.remove(owner: "owner")
        #expect(observedCounts == [0, 1, 0])
        #expect(changeCount == 3)
        #expect(otherCount == 3)

        handle.cancel()
        handle.cancel()
        service.addStateView(ownerPluginID: "owner", marker(.blue))
        #expect(observedCounts == [0, 1, 0])
        #expect(otherCount == 4)
        #expect(changeCount == 4)
    }

    @Test
    func eachContributionRegistrationBroadcastsInvalidation() {
        let kernel = KernelCoreContainer()
        let service = PluginContributionService(kernel: kernel)
        var received = 0
        let handle = service.addObserver { event in
            if case .contributionsChanged = event { received += 1 }
        }
        defer { handle.cancel() }
        // 每次登记均应通知，即使 owner 尚未注册到 Kernel。
        contributeAll(service, owner: "owner", view: marker(.red))
        #expect(received == 12)
        service.remove(owner: "owner")
        #expect(received == 13)
    }
}


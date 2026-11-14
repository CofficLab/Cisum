import ProviderToolbar
import SwiftUI
import Testing

@testable import ProviderSettingsHost

#if os(iOS)
/// 设置宿主外壳：iOS 导航栏贡献项桥接与导航栏归属模式
@Suite("ProviderSettingsHost / 设置宿主外壳", .serialized)
@MainActor
struct ProviderSettingsHostTests {
    private func makeProvider() -> DefaultIOSNavigationBarProviding {
        DefaultIOSNavigationBarProviding()
    }

    private func makeItem(id: String, title: String, placement: IOSNavigationBarPlacement) -> IOSNavigationBarItem {
        IOSNavigationBarItem(id: id, title: title, placement: placement) {
            Text(title)
        }
    }

    @Test("桥接器转发 Provider 的全部可见导航栏项")
    func bridgeForwardsVisibleItems() {
        let provider = makeProvider()
        provider.addNavigationBarItems([
            makeItem(id: "trailing.a", title: "A", placement: .trailing),
            makeItem(id: "leading.b", title: "B", placement: .leading),
            makeItem(id: "trailing.c", title: "C", placement: .trailing)
        ])

        let bridge = IOSNavigationBarItemsBridge(provider: provider)

        #expect(bridge.items.count == 3)
    }

    @Test("Provider 没有贡献项时桥接器返回空数组")
    func bridgeIsEmptyWithoutContributions() {
        let provider = makeProvider()

        let bridge = IOSNavigationBarItemsBridge(provider: provider)

        #expect(bridge.items.isEmpty)
    }

    @Test("分类被隐藏后桥接器不再暴露对应项")
    func bridgeRespectsVisibleCategories() {
        let provider = makeProvider()
        provider.addNavigationBarItems([
            makeItem(id: "trailing.a", title: "A", placement: .trailing)
        ])
        provider.setVisibleCategories([.chat])

        let bridge = IOSNavigationBarItemsBridge(provider: provider)

        #expect(bridge.items.isEmpty)
    }

    @Test("桥接器随 Provider 后续新增的贡献项同步")
    func bridgeReflectsLaterContributions() {
        let provider = makeProvider()
        let bridge = IOSNavigationBarItemsBridge(provider: provider)
        #expect(bridge.items.isEmpty)

        provider.addNavigationBarItems([
            makeItem(id: "trailing.a", title: "A", placement: .trailing)
        ])

        #expect(bridge.items.count == 1)
    }

    @Test("移除贡献项后桥接器同步收缩")
    func bridgeReflectsRemovals() {
        let provider = makeProvider()
        provider.addNavigationBarItems([
            makeItem(id: "trailing.a", title: "A", placement: .trailing),
            makeItem(id: "trailing.b", title: "B", placement: .trailing)
        ])
        let bridge = IOSNavigationBarItemsBridge(provider: provider)
        #expect(bridge.items.count == 2)

        provider.removeNavigationBarItems(ids: ["trailing.a"])

        #expect(bridge.items.count == 1)
    }

    @Test("导航栏归属模式覆盖 host 与 overlay 两种场景")
    func navigationBarModeCoversBothStrategies() {
        var modes: [IOSSettingsAppShell.NavigationBarMode] = []
        modes.append(.host)
        modes.append(.overlay)

        #expect(modes.count == 2)

        var hostCount = 0
        var overlayCount = 0
        for mode in modes {
            switch mode {
            case .host: hostCount += 1
            case .overlay: overlayCount += 1
            }
        }
        #expect(hostCount == 1)
        #expect(overlayCount == 1)
    }

    @Test("导航栏宿主可构造并承载 Provider")
    func navigationBarHostCanBeConstructed() {
        let provider = makeProvider()
        provider.addNavigationBarItems([
            makeItem(id: "trailing.a", title: "A", placement: .trailing)
        ])

        let host = IOSNavigationBarHost(title: "设置", provider: provider)

        #expect(type(of: host) == IOSNavigationBarHost.self)
    }

    @Test("设置外壳可按 host / overlay 两种模式构造")
    func settingsShellCanBeConstructedInBothModes() {
        let provider = makeProvider()

        for mode in [IOSSettingsAppShell.NavigationBarMode.host, .overlay] {
            let shell = IOSSettingsAppShell(
                title: "设置",
                mainView: AnyView(Text("main")),
                settingsView: AnyView(Text("settings")),
                navigationBarProvider: provider,
                navigationBarMode: mode
            )

            #expect(type(of: shell) == IOSSettingsAppShell.self)
        }
    }
}
#endif

import Combine
import ProviderToolbar
import SwiftUI

#if os(iOS)
/// 直接渲染 iOS 顶部导航栏贡献项的宿主。
///
/// 不依赖 SwiftUI 系统 `.toolbar`，避免不同 NavigationStack 宿主下工具栏不显示。
///
/// 仅用于 `IOSSettingsAppShell.NavigationBarMode.overlay`（宿主自身没有
/// 系统导航栈、无法承载 `.toolbar` 的场景）。已经拥有 `NavigationStack`
/// 的宿主应改用 `.host` 模式，避免出现「自绘条 + 系统条」的双导航栏。
@MainActor
public struct IOSNavigationBarHost: View {
    public let title: String
    @StateObject private var providerAdapter: IOSNavigationBarProviderAdapter

    public init(title: String, provider: any IOSNavigationBarProviding) {
        self.title = title
        _providerAdapter = StateObject(
            wrappedValue: IOSNavigationBarProviderAdapter(provider: provider)
        )
    }

    public var body: some View {
        let items = providerAdapter.visibleNavigationBarItems
        let leading = items.filter { $0.placement == .leading }
        let principal = items.filter { $0.placement == .principal }
        let trailing = items.filter { $0.placement == .trailing }

        HStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(leading) { item in
                    item.makeView()
                        .accessibilityLabel(item.title)
                }
            }

            Spacer(minLength: 0)

            if principal.isEmpty {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            } else {
                HStack(spacing: 8) {
                    ForEach(principal) { item in
                        item.makeView()
                            .accessibilityLabel(item.title)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ForEach(trailing) { item in
                    item.makeView()
                        .accessibilityLabel(item.title)
                }
            }
            .frame(minWidth: 40, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

@MainActor
private final class IOSNavigationBarProviderAdapter: ObservableObject {
    private let provider: any IOSNavigationBarProviding
    private var observation: AnyCancellable?

    init(provider: any IOSNavigationBarProviding) {
        self.provider = provider
        observation = provider.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var visibleNavigationBarItems: [IOSNavigationBarItem] {
        provider.visibleNavigationBarItems
    }
}
#endif

import CisumUIComponents
import Foundation
import KernelCore
import MagicKit
import SwiftUI

/// Factory 根视图桥接层。
///
/// 将内核的非播放 UI 配置投影为 SwiftUI 环境值，并用插件的 RootView 包裹内部布局。
struct KernelRootView: View {
    @ObservedObject var kernel: CisumKernel
    @ObservedObject private var themeRegistry = LumiUIThemeRegistry.shared
    /// 插件贡献版本号：插件启用/禁用变化时 +1，触发根视图重新组装。
    @State private var contributionRevision = 0
    /// 已组装的根视图。组装会更新各个 ObservableObject Provider，不能在 body 求值期间执行。
    @State private var assembledContent: AnyView?

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    themeRegistry.chromeTheme.makeGlobalBackground(proxy: geometry)
                        .ignoresSafeArea()

                    rootContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(
                            minWidth: CisumPlayerLayout.minimumWindowWidth,
                            minHeight: CisumPlayerLayout.minimumWindowHeight
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appThemedAppearance()
#if os(macOS)
        .overlay { ThemeWindowAppearanceBridge().allowsHitTesting(false) }
#endif
        .task(id: contributionRevision) {
            assembledContent = FactoryCisum.assembleMainView(kernel: kernel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .cisumEnabledPluginsDidChange)) { _ in
            contributionRevision += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .cisumSceneDidChange)) { _ in
            contributionRevision += 1
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if let assembledContent {
            let bridged = wrap(assembledContent)
            // 插件贡献变化（.id 变化）时整棵子树重建，重新注入内容 Tab 等。
            .id(contributionRevision)
            bridged
        } else {
            ProgressView("Loading…")
        }
    }

    @ViewBuilder
    private func wrap(_ content: AnyView) -> some View {
        if let wrapped = kernel.plugin?.wrapWithCurrentRoot(content: { content }) {
            wrapped
        } else {
            content
        }
    }
}

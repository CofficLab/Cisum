import CisumUIComponents
import LumiUI
import Foundation
import KernelCore
import ProviderPlugin
import CisumProviderPluginManaging
import ProviderScene
import ProviderToast
import MagicKit
import SwiftUI

/// Factory 根视图桥接层。
///
/// 将内核的非播放 UI 配置投影为 SwiftUI 环境值，并用插件的 RootView 包裹内部布局。
struct KernelRootView: View {
    let kernel: KernelCoreContainer
    @ObservedObject private var themeRegistry = LumiUIThemeRegistry.shared
    /// 插件贡献版本号：插件启用/禁用变化时 +1，触发根视图重新组装。
    @StateObject private var providerObserver: KernelRootProviderObserver
    /// 已组装的根视图。组装会更新各个 ObservableObject Provider，不能在 body 求值期间执行。
    @State private var assembledContent: AnyView?

    init(kernel: KernelCoreContainer) {
        self.kernel = kernel
        _providerObserver = StateObject(wrappedValue: KernelRootProviderObserver(kernel: kernel))
    }

    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                ZStack {
                    themeRegistry.chromeTheme.makeGlobalBackground(proxy: geometry)
                        .ignoresSafeArea()

                    rootContent
                        .frame(width: geometry.size.width, height: geometry.size.height)
#if os(macOS)
                        .frame(
                            minWidth: CisumPlayerLayout.minimumWindowWidth,
                            minHeight: CisumPlayerLayout.minimumWindowHeight
                        )
#endif
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .appThemedAppearance()
        .environment(\.toastProviding, kernel.resolveProvider((any ToastProviding).self))
#if os(macOS)
        .overlay { ThemeWindowAppearanceBridge().allowsHitTesting(false) }
#endif
        .task(id: providerObserver.revision) {
            assembledContent = FactoryCisum.assembleMainView(kernel: kernel)
        }
        .onAppear { providerObserver.start() }
        .onDisappear { providerObserver.cancel() }
    }

    @ViewBuilder
    private var rootContent: some View {
        if let assembledContent {
            let bridged = wrap(assembledContent)
            // 插件贡献变化（.id 变化）时整棵子树重建，重新注入内容 Tab 等。
            .id(providerObserver.revision)
            bridged
        } else {
            ProgressView("Loading…")
        }
    }

    @ViewBuilder
    private func wrap(_ content: AnyView) -> some View {
        if let wrapped = kernel.resolveProvider((any PluginProviding).self)?.wrapWithCurrentRoot(content: { content }) {
            wrapped
        } else {
            content
        }
    }
}

@MainActor
private final class KernelRootProviderObserver: ObservableObject {
    @Published private(set) var revision = 0
    private weak var kernel: KernelCoreContainer?
    private var pluginHandle: (any PluginManagingObserverHandle)?
    private var sceneHandle: (any SceneProvidingObserverHandle)?

    init(kernel: KernelCoreContainer) {
        self.kernel = kernel
        start()
    }

    func start() {
        guard pluginHandle == nil, sceneHandle == nil, let kernel else { return }
        pluginHandle = kernel.resolveProvider((any PluginManaging).self)?.addObserver { [weak self] event in
            guard case .enabledPluginsChanged = event else { return }
            self?.revision += 1
        }
        sceneHandle = kernel.resolveProvider((any SceneProviding).self)?.addObserver { [weak self] event in
            guard case .selectionChanged = event else { return }
            self?.revision += 1
        }
    }

    func cancel() {
        pluginHandle?.cancel()
        pluginHandle = nil
        sceneHandle?.cancel()
        sceneHandle = nil
    }
}

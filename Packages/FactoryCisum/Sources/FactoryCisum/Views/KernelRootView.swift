import LumiUI
import Foundation
import KernelCore
import ProviderPlugin
import ProviderPluginManaging
import ProviderScene
import ProviderToast
import ProviderToolbar
import ProviderSettingsHost
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
    #if os(iOS)
    /// iOS 导航栏贡献项桥接器。
    ///
    /// 插件（设置齿轮等）通过 `IOSNavigationBarProviding` 贡献导航栏项，
    /// 由本视图在导航栈级别挂载。桥接器只负责「取值 + 变更转发」。
    @StateObject private var navigationBarItems: IOSNavigationBarItemsBridge
    #endif

    init(kernel: KernelCoreContainer) {
        self.kernel = kernel
        _providerObserver = StateObject(wrappedValue: KernelRootProviderObserver(kernel: kernel))
        #if os(iOS)
        // Provider 可能在插件启动后才注入贡献项，桥接器订阅其变更信号。
        _navigationBarItems = StateObject(wrappedValue: IOSNavigationBarItemsBridge(
            provider: kernel.resolveProvider((any IOSNavigationBarProviding).self)
                ?? DefaultIOSNavigationBarProviding()
        ))
        #endif
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
                            minWidth: AppResponsivePlayerLayoutMetrics.shared.minimumWindowSize.width,
                            minHeight: AppResponsivePlayerLayoutMetrics.shared.minimumWindowSize.height
                        )
#endif
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            #if os(iOS)
            // iOS 侧插件贡献的导航栏项（设置齿轮）要出现在这条系统导航栏上。
            // `NavigationStack` 在本视图内部创建，SwiftUI 不会把外层的
            // `.toolbar` 传递进来，因此由栈的所有者在这里挂载。
            .modifier(IOSNavigationBarToolbarModifier(items: navigationBarItems.items))
            #endif
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
        pluginHandle = kernel.resolveProvider((any PluginManaging).self)?.addPluginObserver { [weak self] event in
            guard case .enabledStateChanged = event else { return }
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

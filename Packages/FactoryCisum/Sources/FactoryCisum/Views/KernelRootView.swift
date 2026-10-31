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
    ///
    /// 初值由宿主在创建内核后**同步**装配好（`WindowMain`）：若让本视图自己在
    /// `.task` 里装配，写入与首次求值存在竞态——视图可能先用「尚未装配」的旧值
    /// 求值，之后 `@State` 里的 `AnyView` 又因没有稳定身份而不再触发重算，
    /// 主窗口就永远停在空态（只有背景，没有音乐库）。
    @State private var assembledContent: AnyView?
    /// 组装计数：每次重新组装 +1，参与视图身份，确保子树重建。
    @State private var assemblyToken: Int = 0
    #if os(iOS)
    /// iOS 导航栏贡献项桥接器。
    ///
    /// 插件（设置齿轮等）通过 `IOSNavigationBarProviding` 贡献导航栏项，
    /// 由本视图在导航栈级别挂载。桥接器只负责「取值 + 变更转发」。
    @StateObject private var navigationBarItems: IOSNavigationBarItemsBridge
    #endif

    init(kernel: KernelCoreContainer, initialContent: AnyView? = nil) {
        self.kernel = kernel
        _assembledContent = State(initialValue: initialContent)
        _assemblyToken = State(initialValue: initialContent == nil ? 0 : 1)
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
                #if os(iOS)
                // iOS 侧插件贡献的导航栏项（设置齿轮）要出现在这条系统导航栏上。
                //
                // 必须挂在 `NavigationStack` **内部**的内容上：`NavigationStack { … }`
                // 自身再接 `.toolbar`，项会被算到**外层**上下文去，不会进入这条
                // 栈自己的导航栏。挂在栈内的内容上才会被这条栈接管（与
                // `RootLayoutView` 内部的 `.toolbar` 落在同一条导航栏）。
                .modifier(IOSNavigationBarToolbarModifier(items: navigationBarItems.items))
                #endif
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
            assemblyToken &+= 1
        }
        .onAppear { providerObserver.start() }
        .onDisappear { providerObserver.cancel() }
    }

    @ViewBuilder
    private var rootContent: some View {
        if let assembledContent {
            let bridged = wrap(assembledContent)
            // 插件贡献变化（.id 变化）时整棵子树重建，重新注入内容 Tab 等。
            //
            // 身份必须**每次组装都不同**：只用 `providerObserver.revision` 时，
            // 首次组装（revision 未变）会复用上一轮（内容尚未就绪）的子树，
            // 结果主窗口永远停在空态。`assemblyToken` 每次组装 +1，
            // 保证子树必然重建。
            .id("\(providerObserver.revision)-\(assemblyToken)")
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
    @Published private(set) var currentScene: AppScene?
    private weak var kernel: KernelCoreContainer?
    private var pluginHandle: (any PluginManagingObserverHandle)?
    private var sceneHandle: (any SceneProvidingObserverHandle)?

    init(kernel: KernelCoreContainer) {
        self.kernel = kernel
        start()
    }

    func start() {
        guard pluginHandle == nil, sceneHandle == nil, let kernel else { return }
        // 初始化当前场景
        currentScene = kernel.resolveProvider((any SceneProviding).self)?.currentScene
        pluginHandle = kernel.resolveProvider((any PluginManaging).self)?.addPluginObserver { [weak self] event in
            guard case .enabledStateChanged = event else { return }
            self?.revision += 1
        }
        sceneHandle = kernel.resolveProvider((any SceneProviding).self)?.addObserver { [weak self] event in
            guard case .selectionChanged(let scene) = event else { return }
            self?.currentScene = scene
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

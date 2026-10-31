import KernelCore
import LumiUI
import ProviderAudioLibrary
import ProviderPlayback
import ProviderPlugin
import ProviderScene
import SwiftUI
import os

private let cisumDebugLogger = Logger(subsystem: "com.coffic.cisum", category: "root-layout-debug")

@MainActor
struct RootLayoutView: View {
    @ObservedObject var provider: RootViewProvider
    @ObservedObject private var themeRegistry = LumiUIThemeRegistry.shared
    @StateObject private var viewModel: RootLayoutViewModel
    @State private var isDetailVisible: Bool
    @State private var rememberedHeight: CGFloat = 0
    @State private var autoResizing = false
    /// 当前场景：用于叠加场景色调背景
    @State private var currentScene: AppScene?
    /// 场景观察者句柄
    @State private var sceneObserverHandle: (any SceneProvidingObserverHandle)?
    let kernel: KernelCoreContainer

    init(provider: RootViewProvider, kernel: KernelCoreContainer) {
        self.provider = provider
        self.kernel = kernel
        // 只在此解析基础设施 Provider（createKernel 早期注册）；
        // 播放/场景/仓库 Provider 由插件注册，必须等内核启动完成后再绑定
        //（见 viewModel.attach），否则贡献聚合期间 resolveProvider 会卡死。
        _viewModel = StateObject(wrappedValue: RootLayoutViewModel(
            contributions: RootContributionCapabilityAdapter(
                plugins: kernel.resolveProvider((any PluginProviding).self)
            )
        ))
        _isDetailVisible = State(initialValue: provider.isContentViewVisible)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                themeRegistry.chromeTheme.makeGlobalBackground(proxy: geometry)

                // 场景色调叠加层：根据当前场景叠加微妙色调，区分不同场景氛围
                sceneTintOverlay
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.4), value: currentScene)

                VStack(spacing: 0) {
                    controlArea
                        .frame(height: isDetailVisible
                            ? (viewModel.isPlaybackHeroPresenting
                                ? AppResponsivePlayerLayoutMetrics.shared.controlMinimumHeight
                                : AppResponsivePlayerLayoutMetrics.shared.emptyControlHeight)
                            : geometry.size.height)

                    if isDetailVisible {
                        contentArea
                            .frame(minHeight: AppResponsivePlayerLayoutMetrics.shared.contentMinimumHeight, maxHeight: .infinity)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    statusArea
                }
                .frame(width: layoutWidth(for: geometry), height: layoutHeight(for: geometry))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .onAppear {
                handleOnAppear()
                // 能力在此组装：View 是本能力的组装层，容器不触碰 Provider。
                viewModel.attach(environment: RootEnvironmentCapabilityAdapter(
                    playback: kernel.resolveProvider((any PlaybackProviding).self),
                    scene: kernel.resolveProvider((any SceneProviding).self),
                    library: kernel.resolveProvider((any AudioLibraryProviding).self)
                ))
                // 场景色调观察：初始化当前场景并订阅变更
                if let sceneProvider = kernel.resolveProvider((any SceneProviding).self) {
                    currentScene = sceneProvider.currentScene
                    sceneObserverHandle = sceneProvider.addObserver { event in
                        guard case .selectionChanged(let scene) = event else { return }
                        // @State 内部使用引用类型存储，通过闭包修改是安全的
                        // 句柄在 onDisappear 时取消，避免泄漏
                        DispatchQueue.main.async {
                            self.currentScene = scene
                        }
                    }
                }
            }
            .onDisappear {
                sceneObserverHandle?.cancel()
                sceneObserverHandle = nil
            }
            .onChange(of: provider.isContentViewHidden) { _, hidden in
                handleContentViewVisibilityChange(!hidden, geometry: geometry)
            }
            .onChange(of: geometry.size.height) { _, newHeight in
                handleGeometryChange(newHeight)
            }
        }
        .appThemedAppearance()
        .toolbar {
            // 引导层（如首启存储选择）会通过根视图契约隐藏工具栏：
            // 抑制而非遮挡——工具栏是真实控件，必须停止贡献才真正消失。
            if !provider.isToolbarViewHidden {
                ToolbarItem(placement: .navigation) {
                    provider.toolbarView ?? AnyView(EmptyView())
                }
                if !viewModel.toolbarButtons.isEmpty {
                    // 这里不能放 Spacer()：iOS 26 起 ToolbarItemGroup 会把整组内容收进
                    // 一颗 Liquid Glass 胶囊，组内的弹性 Spacer 会把胶囊撑宽、
                    // 把按钮推到胶囊尾端，于是图标左边留下一段空白玻璃。
                    // macOS 工具栏不需要它（按钮本就靠右），去掉对两端都无影响。
                    ToolbarItemGroup(placement: .cancellationAction) {
                        ForEach(Array(viewModel.toolbarButtons.enumerated()), id: \.offset) { _, item in
                            item.view
                        }
                    }
                }
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.cancel() }
    }

    // MARK: - Scene Tint Overlay

    /// 场景色调叠加层：根据当前场景叠加微妙色调，区分不同场景氛围。
    ///
    /// 音乐场景使用冷蓝色调，有声书场景使用暖棕色调。
    /// 色调透明度较低，仅作为氛围点缀，不影响内容可读性。
    @ViewBuilder
    private var sceneTintOverlay: some View {
        switch currentScene {
        case .music:
            Color(red: 0.10, green: 0.18, blue: 0.32).opacity(0.15)
        case .audiobooks:
            Color(red: 0.32, green: 0.20, blue: 0.10).opacity(0.15)
        case nil:
            Color.clear
        }
    }

    @ViewBuilder
    private var controlArea: some View {
        if let controlView = provider.controlView {
            controlView
        } else {
            ContentPlaceholderView()
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if let contentView = provider.contentView {
            contentView
        } else {
            ContentPlaceholderView()
        }
    }

    @ViewBuilder
    private var statusArea: some View {
        if let statusView = provider.statusBarView {
            statusView
        } else {
            HStack {
                Spacer()
                ForEach(Array(viewModel.statusViews.enumerated()), id: \.offset) { _, view in
                    view
                }
            }
        }
    }

    private func handleOnAppear() {
        rememberedHeight = windowHeight()
        isDetailVisible = provider.isContentViewVisible
        if isDetailVisible, rememberedHeight > 0,
           AppResponsivePlayerLayoutMetrics.shared.needsExpandedWindow(for: rememberedHeight) {
            autoResizing = true
            setWindowHeight(AppResponsivePlayerLayoutMetrics.shared.controlMinimumHeight + AppResponsivePlayerLayoutMetrics.shared.contentMinimumHeight)
        }
    }

    private func handleContentViewVisibilityChange(_ visible: Bool, geometry: GeometryProxy) {
        withAnimation { isDetailVisible = visible }

        if !visible, abs(geometry.size.height - rememberedHeight) > 0.5, rememberedHeight > 0 {
            autoResizing = true
            setWindowHeight(rememberedHeight)
        } else if visible, AppResponsivePlayerLayoutMetrics.shared.needsExpandedWindow(for: currentWindowHeight(geometry: geometry)) {
            autoResizing = true
            setWindowHeight(AppResponsivePlayerLayoutMetrics.shared.controlMinimumHeight + AppResponsivePlayerLayoutMetrics.shared.contentMinimumHeight)
        }
    }

    private func handleGeometryChange(_ newHeight: CGFloat) {
        if !autoResizing { rememberedHeight = windowHeight() }
        autoResizing = false
        if RootContentVisibility.shouldHideContentView(
            isMacOS: RootContentVisibility.hostIsMacOS,
            newHeight: newHeight,
            dropThreshold: AppResponsivePlayerLayoutMetrics.shared.secondaryColumnDropHeightThreshold
        ) {
            provider.hideContentView()
        }
    }

    /// 当前**窗口**高度（拿不到窗口时退回布局高度）。
    ///
    /// `needsExpandedWindow(for:)` 的语义是「窗口够不够高」，参数必须是
    /// 窗口高度。若误用 `geometry.size.height`（内容区高度，扣掉了标题栏等
    /// 窗口装饰），展开内容区时会把一个本来足够高的窗口误判为「不够高」，
    /// 反而把它**缩小**——缩小后内容区高度又低于收起阈值，于是内容区刚
    /// 展开就被立刻收起，「更多」按钮表现为「点了没反应」。
    private func currentWindowHeight(geometry: GeometryProxy) -> CGFloat {
        let height = windowHeight()
        return height > 0 ? height : geometry.size.height
    }

    private func windowHeight() -> CGFloat {
#if os(macOS)
        let window = contentWindow()
        return window?.frame.height ?? 0
#else
        0
#endif
    }

    private func layoutWidth(for geometry: GeometryProxy) -> CGFloat {
#if os(macOS)
        let window = contentWindow()
        guard let window else { return geometry.size.width }
        let w = min(geometry.size.width, max(0, window.frame.width))
        cisumDebugLogger.error("LAYOUT-DEBUG geomW=\(geometry.size.width) geomH=\(geometry.size.height) winFrameW=\(window.frame.width) winContentW=\(window.contentLayoutRect.width) winContentH=\(window.contentLayoutRect.height) layoutW=\(w) overflow=\(self.horizontalOverflow(for: geometry)) screenW=\(window.screen?.frame.width ?? -1)")
        return w
#else
        geometry.size.width
#endif
    }

    private func layoutHeight(for geometry: GeometryProxy) -> CGFloat {
#if os(macOS)
        let window = contentWindow()
        guard let window else { return geometry.size.height }
        return min(geometry.size.height, max(0, window.contentLayoutRect.height))
#else
        geometry.size.height
#endif
    }

    private func horizontalOverflow(for geometry: GeometryProxy) -> CGFloat {
#if os(macOS)
        guard let window = contentWindow() else { return 0 }
        return AppResponsivePlayerLayoutMetrics.shared.horizontalCenteringOffset(
            proposedWidth: geometry.size.width,
            visibleWidth: window.frame.width
        )
#else
        0
#endif
    }

    private func setWindowHeight(_ height: CGFloat) {
#if os(macOS)
        guard height.isFinite,
              let window = contentWindow() else { return }
        var frame = window.frame
        frame.origin.y += frame.height - height
        frame.size.height = height
        window.setFrame(frame, display: true)
#else
        _ = height
#endif
    }

#if os(macOS)
    private func contentWindow() -> NSWindow? {
        return mainApplicationWindow()
    }

    /// Always resolves the main content window, even while Settings is key.
    private func mainApplicationWindow() -> NSWindow? {
        NSApplication.shared.windows.first(where: {
            $0.isVisible
                && $0.canBecomeMain
                && $0.identifier?.rawValue != "cisum.settings"
                && $0.title != "设置"
                && $0.title != "Settings"
        })
            ?? NSApplication.shared.mainWindow
            ?? NSApplication.shared.windows.first(where: { $0.isVisible && $0.canBecomeKey })
            ?? NSApplication.shared.windows.first
    }
#endif
}

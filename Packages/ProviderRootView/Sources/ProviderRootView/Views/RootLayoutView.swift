import CisumUIComponents
import LumiUI
import KernelCore
import ProviderPlugin
import KitAppEvents
import SwiftUI

/// 根布局视图（迁移自 FactoryCisum `AppLayoutView`）。
///
/// 结构：顶部播放控制区 + 中间内容区 + 底部状态区；工具栏含「显示/隐藏内容」
/// 按钮与插件贡献的工具栏按钮（含场景切换器）。各区域优先使用 Provider 注入
/// 的视图，否则回退默认实现。
struct RootLayoutView: View {
    @ObservedObject private var viewModel: RootLayoutViewModel
    @ObservedObject private var themeRegistry = LumiUIThemeRegistry.shared
    let provider: DefaultRootViewProvider
    let kernel: KernelCoreContainer
    @State private var isDetailVisible = false
    @State private var rememberedHeight: CGFloat = 0
    @State private var autoResizing = false

    init(provider: DefaultRootViewProvider, kernel: KernelCoreContainer) {
        _viewModel = ObservedObject(wrappedValue: RootLayoutViewModel(
            provider: provider,
            pluginProvider: kernel.resolveProvider((any PluginProviding).self)
        ))
        _isDetailVisible = State(initialValue: provider.isContentViewVisible)
        self.provider = provider
        self.kernel = kernel
    }

    private var isContentVisible: Bool { viewModel.isContentViewVisible }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                themeRegistry.chromeTheme.makeGlobalBackground(proxy: geometry)

                VStack(spacing: 0) {
                    if isDetailVisible {
                        controlArea
                            .frame(height: CisumPlayerLayout.controlMinimumHeight)
                    } else {
                        controlArea
                            // The collapsed player owns the whole available
                            // window height. A max-height proposal lets the
                            // injected control view choose its ideal height,
                            // which can put the bottom buttons outside the
                            // window when the window is at its minimum size.
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }

                    if isDetailVisible {
                        contentArea
                            .frame(minHeight: CisumPlayerLayout.contentMinimumHeight, maxHeight: .infinity)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    statusArea
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(x: -horizontalOverflow(for: geometry))
            }
            .onAppear { handleOnAppear() }
            .onChange(of: viewModel.isContentViewVisible) { _, newValue in
                handleContentViewVisibilityChange(newValue, geometry: geometry)
            }
            .onChange(of: geometry.size.height) { _, newHeight in
                handleGeometryChange(newHeight)
            }
        }
        .appThemedAppearance()
        .toolbar {
            ToolbarItem(placement: .navigation) {
                toolbarArea
            }
            if !pluginToolbarButtons.isEmpty {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Spacer()
                    ForEach(Array(pluginToolbarButtons.enumerated()), id: \.offset) { _, item in
                        item.view
                    }
                }
            }
        }
    }

    /// Toolbar contributions arrive asynchronously during plugin startup. Read
    /// the observed revision here so SwiftUI reevaluates the toolbar after the
    /// provider publishes a contribution change.
    private var pluginToolbarButtons: [(id: String, view: AnyView)] {
        _ = viewModel.pluginContributionRevision
        return kernel.resolveProvider((any PluginProviding).self)?.getToolBarButtons() ?? []
    }

    @ViewBuilder
    private var controlArea: some View {
        if let controlView = viewModel.controlView {
            controlView
        } else {
            ContentPlaceholderView()
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if let contentView = viewModel.contentView {
            contentView
        } else {
            ContentPlaceholderView()
        }
    }

    @ViewBuilder
    private var statusArea: some View {
        if let statusView = viewModel.statusView {
            statusView
        } else {
            HStack {
                Spacer()
                ForEach(Array((kernel.resolveProvider((any PluginProviding).self)?.getStatusViews() ?? []).enumerated()), id: \.offset) { _, view in
                    view
                }
            }
        }
    }

    @ViewBuilder
    private var toolbarArea: some View {
        if let toolbarContent = viewModel.toolbarContent {
            toolbarContent
        }
    }

    private func handleOnAppear() {
        rememberedHeight = windowHeight()
        isDetailVisible = isContentVisible

        if isContentVisible, rememberedHeight > 0,
           CisumPlayerLayout.needsExpandedWindow(for: rememberedHeight) {
            autoResizing = true
            setWindowHeight(
                CisumPlayerLayout.controlMinimumHeight + CisumPlayerLayout.contentMinimumHeight
            )
        }
    }

    private func handleContentViewVisibilityChange(_ newValue: Bool, geometry: GeometryProxy) {
        withAnimation {
            isDetailVisible = newValue
        }

        if !newValue, abs(geometry.size.height - rememberedHeight) > 0.5, rememberedHeight > 0 {
            autoResizing = true
            setWindowHeight(rememberedHeight)
        } else if newValue, CisumPlayerLayout.needsExpandedWindow(for: geometry.size.height) {
            autoResizing = true
            setWindowHeight(
                CisumPlayerLayout.controlMinimumHeight + CisumPlayerLayout.contentMinimumHeight
            )
        }
    }

    private func handleGeometryChange(_ newHeight: CGFloat) {
        if !autoResizing {
            rememberedHeight = windowHeight()
        }
        autoResizing = false

        if newHeight <= CisumPlayerLayout.collapsedWindowThresholdHeight {
            provider.hideContentView()
        }
    }

    private func windowHeight() -> CGFloat {
        #if os(macOS)
            let window = NSApplication.shared.keyWindow
                ?? NSApplication.shared.mainWindow
                ?? NSApplication.shared.windows.first(where: { $0.isVisible && $0.canBecomeKey })
                ?? NSApplication.shared.windows.first
            return window?.frame.height ?? 0
        #else
            0
        #endif
    }

    /// Some macOS hosting configurations can propose a view width larger than
    /// the visible window content area. Keep centered player/repository content
    /// centered in the actual window instead of centering it in the oversized
    /// proposal and clipping its trailing edge.
    private func horizontalOverflow(for geometry: GeometryProxy) -> CGFloat {
        #if os(macOS)
            let window = NSApplication.shared.keyWindow
                ?? NSApplication.shared.mainWindow
                ?? NSApplication.shared.windows.first(where: { $0.isVisible && $0.canBecomeKey })
                ?? NSApplication.shared.windows.first
            guard let window else { return 0 }
            return CisumPlayerLayout.horizontalCenteringOffset(
                proposedWidth: geometry.size.width,
                visibleWidth: window.contentLayoutRect.width
            )
        #else
            0
        #endif
    }

    private func setWindowHeight(_ height: CGFloat) {
        #if os(macOS)
            guard height.isFinite,
                  let window = NSApplication.shared.keyWindow
                    ?? NSApplication.shared.mainWindow
                    ?? NSApplication.shared.windows.first(where: { $0.isVisible && $0.canBecomeKey })
                    ?? NSApplication.shared.windows.first else { return }
            var frame = window.frame
            frame.origin.y += frame.height - height
            frame.size.height = height
            window.setFrame(frame, display: true)
        #else
            _ = height
        #endif
    }
}

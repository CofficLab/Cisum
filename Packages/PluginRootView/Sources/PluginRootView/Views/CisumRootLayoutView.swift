import CisumUIComponents
import KernelCore
import LumiUI
import ProviderPlugin
import SwiftUI
import os

private let cisumDebugLogger = Logger(subsystem: "com.coffic.cisum", category: "root-layout-debug")

@MainActor
struct CisumRootLayoutView: View {
    @ObservedObject var provider: CisumRootViewProvider
    @ObservedObject private var themeRegistry = LumiUIThemeRegistry.shared
    @StateObject private var viewModel: CisumRootLayoutViewModel
    @State private var isDetailVisible: Bool
    @State private var rememberedHeight: CGFloat = 0
    @State private var autoResizing = false
    @State private var isPlaybackHeroVisible = true
    let kernel: KernelCoreContainer

    init(provider: CisumRootViewProvider, kernel: KernelCoreContainer) {
        self.provider = provider
        self.kernel = kernel
        _viewModel = StateObject(wrappedValue: CisumRootLayoutViewModel(
            pluginProvider: kernel.resolveProvider((any PluginProviding).self)
        ))
        _isDetailVisible = State(initialValue: provider.isContentViewVisible)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                themeRegistry.chromeTheme.makeGlobalBackground(proxy: geometry)

                VStack(spacing: 0) {
                    controlArea
                        .frame(height: isDetailVisible
                            ? (isPlaybackHeroVisible
                                ? CisumPlayerLayout.controlMinimumHeight
                                : CisumPlayerLayout.emptyPlayerControlHeight)
                            : geometry.size.height)

                    if isDetailVisible {
                        contentArea
                            .frame(minHeight: CisumPlayerLayout.contentMinimumHeight, maxHeight: .infinity)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    statusArea
                }
                .frame(width: layoutWidth(for: geometry), height: layoutHeight(for: geometry))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .environment(\.playbackHeroVisibility, $isPlaybackHeroVisible)
            .onAppear { handleOnAppear() }
            .onChange(of: provider.isContentViewHidden) { _, hidden in
                handleContentViewVisibilityChange(!hidden, geometry: geometry)
            }
            .onChange(of: geometry.size.height) { _, newHeight in
                handleGeometryChange(newHeight)
            }
        }
        .appThemedAppearance()
        .toolbar {
            ToolbarItem(placement: .navigation) {
                provider.toolbarView ?? AnyView(EmptyView())
            }
            if !viewModel.toolbarButtons.isEmpty {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Spacer()
                    ForEach(Array(viewModel.toolbarButtons.enumerated()), id: \.offset) { _, item in
                        item.view
                    }
                }
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.cancel() }
    }

    @ViewBuilder
    private var controlArea: some View {
        if let controlView = provider.controlView {
            controlView
        } else {
            CisumContentPlaceholderView()
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if let contentView = provider.contentView {
            contentView
        } else {
            CisumContentPlaceholderView()
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
           CisumPlayerLayout.needsExpandedWindow(for: rememberedHeight) {
            autoResizing = true
            setWindowHeight(CisumPlayerLayout.controlMinimumHeight + CisumPlayerLayout.contentMinimumHeight)
        }
    }

    private func handleContentViewVisibilityChange(_ visible: Bool, geometry: GeometryProxy) {
        withAnimation { isDetailVisible = visible }

        if !visible, abs(geometry.size.height - rememberedHeight) > 0.5, rememberedHeight > 0 {
            autoResizing = true
            setWindowHeight(rememberedHeight)
        } else if visible, CisumPlayerLayout.needsExpandedWindow(for: geometry.size.height) {
            autoResizing = true
            setWindowHeight(CisumPlayerLayout.controlMinimumHeight + CisumPlayerLayout.contentMinimumHeight)
        }
    }

    private func handleGeometryChange(_ newHeight: CGFloat) {
        if !autoResizing { rememberedHeight = windowHeight() }
        autoResizing = false
        if newHeight <= CisumPlayerLayout.collapsedWindowThresholdHeight {
            provider.hideContentView()
        }
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
        return CisumPlayerLayout.horizontalCenteringOffset(
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

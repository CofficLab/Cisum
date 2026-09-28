import CisumUIComponents
import KernelCore
import LumiUI
import ProviderPlugin
import SwiftUI

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
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(x: -horizontalOverflow(for: geometry))
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
        let window = NSApplication.shared.keyWindow
            ?? NSApplication.shared.mainWindow
            ?? NSApplication.shared.windows.first(where: { $0.isVisible && $0.canBecomeKey })
            ?? NSApplication.shared.windows.first
        return window?.frame.height ?? 0
#else
        0
#endif
    }

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

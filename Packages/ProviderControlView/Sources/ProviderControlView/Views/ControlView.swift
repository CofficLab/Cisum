import CisumUIComponents
import SwiftUI

/// 播放控制区域：封面、标题、状态、进度条和底部操作按钮。
///
/// 各区块（封面 / 状态 / 进度 / 操作按钮 / 右侧封面）可分别注入自定义视图，
/// 未注入时不渲染播放相关区块。封面区、进度条、操作按钮组和右侧专辑区由插件注入
/// （`setHeroView` / `setProgressView` / `setControlButtonsView`），
/// 未注入时不渲染该区块。
struct ControlView: View {
    let stateViews: @MainActor () -> [AnyView]
    let stateMessage: @MainActor () -> String
    let isDemoMode: Bool
    var heroView: AnyView? = nil
    var stateView: AnyView? = nil
    var progressView: AnyView? = nil
    var controlButtonsView: AnyView? = nil
    var rightAlbumView: AnyView? = nil

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    if heroView != nil {
                        heroArea(for: geometry)
                            .frame(maxWidth: .infinity)
                            .frame(height: heroHeight(for: geometry), alignment: .top)
                    }

                    stateArea
                        .frame(height: stateHeight(for: geometry))
                        .frame(maxWidth: .infinity)

                    if progressView != nil {
                        progressArea
                            .frame(height: progressContentHeight)
                            .padding(.horizontal)
                            .padding(.vertical, progressVerticalPadding)
                    }

                    if controlButtonsView != nil {
                        buttonsArea
                            .frame(height: buttonHeight(for: geometry))
                            .frame(maxWidth: .infinity)
                    }
                }

                if shouldShowRightAlbum(geometry) {
                    HStack {
                        Spacer(minLength: 0)
                        rightAlbumArea
                    }
                    .frame(maxWidth: geometry.size.height * 1.3)
                }
            }
            .padding(.bottom, 0)
            .padding(.horizontal, 0)
            .frame(maxHeight: .infinity)
        }
        #if os(macOS)
            .ignoresSafeArea(edges: .horizontal)
        #else
            .ignoresSafeArea()
        #endif
        .frame(minHeight: CisumPlayerLayout.controlMinimumHeight)
    }

    @ViewBuilder
    private func heroArea(for geometry: GeometryProxy) -> some View {
        if let heroView {
            heroView
        }
    }

    @ViewBuilder
    private var stateArea: some View {
        if let stateView {
            stateView
        } else {
            StateView(isDemoMode: isDemoMode, stateViews: stateViews, stateMessage: stateMessage)
        }
    }

    @ViewBuilder
    private var progressArea: some View {
        if let progressView {
            progressView
        }
    }

    @ViewBuilder
    private var buttonsArea: some View {
        if let controlButtonsView {
            controlButtonsView
        }
    }

    @ViewBuilder
    private var rightAlbumArea: some View {
        if let rightAlbumView {
            rightAlbumView
        }
    }

    private func stateHeight(for geometry: GeometryProxy) -> CGFloat {
        CisumPlayerLayout.stateHeight(for: geometry.size.height)
    }

    private func heroHeight(for geometry: GeometryProxy) -> CGFloat {
        let reservedHeight = stateHeight(for: geometry)
            + (progressView == nil ? 0 : progressContentHeight + progressVerticalPadding * 2)
            + (controlButtonsView == nil ? 0 : buttonHeight(for: geometry))

        return max(0, geometry.size.height - reservedHeight)
    }

    private func buttonHeight(for geometry: GeometryProxy) -> CGFloat {
        CisumPlayerLayout.controlButtonHeight(width: geometry.size.width, height: geometry.size.height)
    }

    private let progressContentHeight: CGFloat = 18
    private let progressVerticalPadding: CGFloat = 8

    private func shouldShowRightAlbum(_ geometry: GeometryProxy) -> Bool {
        CisumPlayerLayout.shouldShowRightAlbum(width: geometry.size.width)
    }
}

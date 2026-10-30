import LumiUI
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
    /// 空仓库引导插槽（顶部引导视图）。
    var guideSlot: ControlGuideSlot? = nil
    /// 引导插槽的观察者：激活态变化时控制区需要重新排布（引导占顶部、控件沉底）。
    @ObservedObject private var observedGuideSlot: ControlGuideSlot
    /// 播放器区呈现状态：由 PluginPlaybackHero 的 Observer 驱动（事件直达），
    /// 不再经 preference 自底向上传递（该链路会停留在默认值，收起断言恒失败）。
    @ObservedObject private var heroVisibility = ControlHeroVisibility.shared

    private var isHeroVisible: Bool { heroVisibility.isVisible }

    @MainActor
    init(
        stateViews: @escaping @MainActor () -> [AnyView],
        stateMessage: @escaping @MainActor () -> String,
        isDemoMode: Bool,
        heroView: AnyView? = nil,
        stateView: AnyView? = nil,
        progressView: AnyView? = nil,
        controlButtonsView: AnyView? = nil,
        rightAlbumView: AnyView? = nil,
        guideSlot: ControlGuideSlot? = nil
    ) {
        self.stateViews = stateViews
        self.stateMessage = stateMessage
        self.isDemoMode = isDemoMode
        self.heroView = heroView
        self.stateView = stateView
        self.progressView = progressView
        self.controlButtonsView = controlButtonsView
        self.rightAlbumView = rightAlbumView
        self.guideSlot = guideSlot
        _observedGuideSlot = ObservedObject(wrappedValue: guideSlot ?? .inactive)
    }

    var body: some View {
        GeometryReader { geometry in
            let showsGuide = shouldShowGuide(in: geometry)

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    if showsGuide {
                        // 空仓库引导：占据顶部主要区域，把播放控件压到底部。
                        guideArea
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if heroView != nil {
                        heroArea(for: geometry)
                            .frame(maxWidth: .infinity)
                            .frame(height: isHeroVisible ? heroHeight(for: geometry) : 0, alignment: .top)
                            .animation(.easeInOut(duration: 0.2), value: isHeroVisible)
                    }

                    stateArea
                        .frame(height: stateHeight(for: geometry))
                        .frame(maxWidth: .infinity)

                    if showsProgressSection {
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
        .frame(minHeight: isHeroVisible
            ? AppResponsivePlayerLayoutMetrics.shared.controlMinimumHeight
            : AppResponsivePlayerLayoutMetrics.shared.emptyControlHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cisum.player.controls")
    }

    /// 呈现空仓库引导的条件：插槽已激活、封面区未呈现、控制区高度足够。
    ///
    /// 封面区与引导互斥：仓库为空时不会存在「正在呈现封面」的状态，两者同时
    /// 成立会让两者争抢剩余高度（引导要 `maxHeight: .infinity`，封面要固定高度）。
    private func shouldShowGuide(in geometry: GeometryProxy) -> Bool {
        guard observedGuideSlot.isActive else { return false }
        guard !isHeroVisible else { return false }
        return geometry.size.height >= Self.guideMinimumHeight
    }

    /// 进度区是否呈现。
    ///
    /// 引导激活意味着「音乐仓库是空的」——没有可播的曲目，进度条也就没有
    /// 进度可言。这时连同它占的高度一起收掉，而不是留一条空荡荡的槽。
    ///
    /// 用引导插槽的激活态当信号，是因为它已经带上了「音乐场景 + 仓库为空」
    /// 两个前提：切到有声书场景时插槽不激活，那边的播放进度照常显示。
    private var showsProgressSection: Bool {
        progressView != nil && !observedGuideSlot.isActive
    }

    @ViewBuilder
    private var guideArea: some View {
        observedGuideSlot.guideView
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
        AppResponsivePlayerLayoutMetrics.shared.stateHeight(for: geometry.size.height)
    }

    private func heroHeight(for geometry: GeometryProxy) -> CGFloat {
        let reservedHeight = stateHeight(for: geometry)
            + (showsProgressSection ? progressContentHeight + progressVerticalPadding * 2 : 0)
            + (controlButtonsView == nil ? 0 : buttonHeight(for: geometry))

        return max(0, geometry.size.height - reservedHeight)
    }

    private func buttonHeight(for geometry: GeometryProxy) -> CGFloat {
        AppResponsivePlayerLayoutMetrics.shared.controlButtonHeight(width: geometry.size.width, height: geometry.size.height)
    }

    private let progressContentHeight: CGFloat = 18
    private let progressVerticalPadding: CGFloat = 8

    /// 呈现空仓库引导所需的最小控制区高度。
    ///
    /// 内容区展开时控制区只有 150pt（`emptyControlHeight`），塞不下引导面板；
    /// 此时保持原样——引导不出现，播放控件照常呈现。只有仓库视图收起、
    /// 控制区占满窗口时，顶部才有足够空间承载引导。
    static let guideMinimumHeight: CGFloat = 320

    private func shouldShowRightAlbum(_ geometry: GeometryProxy) -> Bool {
        AppResponsivePlayerLayoutMetrics.shared.shouldShowSecondaryColumn(width: geometry.size.width)
    }
}

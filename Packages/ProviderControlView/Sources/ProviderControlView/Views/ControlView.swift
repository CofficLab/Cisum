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
    /// 载入中插槽（激活时替代状态行 + 进度行）。
    var loadingSlot: ControlLoadingSlot? = nil
    /// 引导插槽的观察者：激活态变化时控制区需要重新排布（引导占顶部、控件沉底）。
    @ObservedObject private var observedGuideSlot: ControlGuideSlot
    /// 载入插槽的观察者：激活态变化时控制区需要在两行与单块之间切换。
    @ObservedObject private var observedLoadingSlot: ControlLoadingSlot
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
        guideSlot: ControlGuideSlot? = nil,
        loadingSlot: ControlLoadingSlot? = nil
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
        self.loadingSlot = loadingSlot
        _observedGuideSlot = ObservedObject(wrappedValue: guideSlot ?? .inactive)
        _observedLoadingSlot = ObservedObject(wrappedValue: loadingSlot ?? .inactive)
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

                    if showsLoadingSection {
                        loadingArea
                            .frame(height: loadingHeight(for: geometry))
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 10)
                    } else {
                        stateArea
                            .frame(height: stateHeight(for: geometry))
                            .frame(maxWidth: .infinity)

                        if showsProgressSection {
                            progressArea
                                .frame(height: progressContentHeight)
                                .padding(.horizontal)
                                .padding(.vertical, progressVerticalPadding)
                        }
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

    /// 呈现空仓库引导的条件：插槽已激活、控制区高度足够。
    ///
    /// 引导优先于封面区：仓库为空时，有声书插件仍会为「挑一本」idle 占位
    /// 声明封面呈现态，但那一屏该由引导接管，否则两个场景的空状态长得不一样。
    /// 引导占据顶部主要区域，封面区在其激活期间不渲染，避免争抢剩余高度。
    private func shouldShowGuide(in geometry: GeometryProxy) -> Bool {
        guard observedGuideSlot.isActive else { return false }
        return geometry.size.height >= Self.guideMinimumHeight
    }

    /// 进度区是否呈现。
    ///
    /// 引导激活意味着当前场景的仓库是空的——没有可播的内容，进度条也就没有
    /// 进度可言。这时连同它占的高度一起收掉，而不是留一条空荡荡的槽。
    ///
    /// 插槽的激活条件本身就带上了「当前场景 + 仓库为空」（音乐读音频仓库，
    /// 有声书读书库），所以这里的判断对两个场景同时成立。
    ///
    /// 载入插槽激活时进度行同样收掉——横幅已经占用了「状态 + 进度」的
    /// 整块空间，不能再叠一条时间轴。
    private var showsProgressSection: Bool {
        progressView != nil && !observedGuideSlot.isActive && !showsLoadingSection
    }

    /// 载入插槽是否替代状态行与进度行。
    ///
    /// 引导优先：空仓库不可能同时有内容在载入，两者同时成立时以引导为准。
    private var showsLoadingSection: Bool {
        observedLoadingSlot.isActive && !observedGuideSlot.isActive
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
    private var loadingArea: some View {
        if let loadingSlot {
            loadingSlot.view
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

    /// 载入横幅高度：等于状态行与进度行（内容 + 上下留白）之和，
    /// 保证激活时只是换内容而不改变控制区总高度。
    private func loadingHeight(for geometry: GeometryProxy) -> CGFloat {
        stateHeight(for: geometry) + progressContentHeight + progressVerticalPadding * 2
    }

    private func heroHeight(for geometry: GeometryProxy) -> CGFloat {
        let reservedHeight = stateHeight(for: geometry)
            + ((showsLoadingSection || showsProgressSection)
                ? progressContentHeight + progressVerticalPadding * 2 : 0)
            + (controlButtonsView == nil ? 0 : buttonHeight(for: geometry))

        return max(0, geometry.size.height - reservedHeight)
    }

    private func buttonHeight(for geometry: GeometryProxy) -> CGFloat {
        let reserved = AppResponsivePlayerLayoutMetrics.shared.controlButtonHeight(
            width: geometry.size.width,
            height: geometry.size.height
        )
        #if os(visionOS)
        // 与 PluginAudioControlButtons.ControlButtonsView / PluginBookControlButtons
        // BookControlButtonsView 的按钮直径下限（60pt）保持一致：预留行高必须
        // 覆盖「直径 + 底部留白」，否则按钮被行高截断。
        return max(reserved, 60 + AppResponsivePlayerLayoutMetrics.shared.controlButtonBottomPadding)
        #else
        return reserved
        #endif
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

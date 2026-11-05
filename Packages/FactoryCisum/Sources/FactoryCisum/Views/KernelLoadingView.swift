import LumiUI
import SwiftUI

/// 内核启动加载视图。
///
/// ## 设计意图
///
/// 启动期间用户只能看到这一屏，因此它承担两件事：
///
/// 1. **不吓人的等待**：早期版本是一块纯黑底 + 系统灰 spinner + 一行小字，
///    在主题化的主界面之前显得非常粗糙。现在改为跟随应用主题的品牌页：
///    品牌胶片标记 + 旋转光环 + 与主界面同源的渐变背景。
/// 2. **有内容的等待**：内核启动要经历「创建内核 → 启动插件 → 组装视图」
///    三个阶段，文案随阶段推进，让用户知道 App 正在做什么，而不是
///    怀疑它卡住了。
///
/// ## 两处关键设计
///
/// **背景必须与主界面同源。** 早期版本用的是 `theme.background`，而主界面
/// 用的是 `chromeTheme.makeGlobalBackground(proxy:)`。启动阶段主题尚未注册，
/// 前者会回退成暗色、后者是真实配色，于是加载页暗 → 主界面亮，出现明显
/// 的明暗闪烁。现在加载页直接复用主界面的全局背景，两者必然一致。
///
/// **内容延迟露出。** 内核启动在 macOS 上仅需百毫秒量级，此时展示任何
/// 加载页都只是让用户看到一次闪烁。因此品牌标记与文案延迟一小段时间
/// 才出现：启动够快，这一屏根本不会出现；启动确实慢，它才作为「有内容
/// 的等待」发挥作用。背景始终立即绘制，保证窗口不会是一片空白。
struct KernelLoadingView: View {
    /// 内容延迟露出的时长。
    ///
    /// 取值权衡：短于此值会看到加载页一闪（比不显示更糟），长于此值则
    /// 真正缓慢的启动要多等一段才看到反馈。400ms 是「用户开始留意等待」
    /// 的常见阈值。
    private static let contentRevealDelay = Duration.milliseconds(400)

    @ObservedObject private var themeRegistry = LumiUIThemeRegistry.shared
    @LumiTheme private var theme
    @Environment(\.colorScheme) private var colorScheme
    @LumiMotionPreferenceReader private var motionPreference

    /// 启动阶段。
    private enum Stage: Int, CaseIterable {
        case starting
        case loadingPlugins
        case preparingInterface

        /// 阶段对应的本地化文案键。
        var messageKey: LocalizedStringKey {
            switch self {
            case .starting: "Starting Cisum…"
            case .loadingPlugins: "Loading media library…"
            case .preparingInterface: "Preparing the interface…"
            }
        }
    }

    /// 当前阶段。
    @State private var stage: Stage = .starting

    /// 是否已到「内容露出」的时机。
    @State private var revealsContent = false

    /// 阶段推进任务句柄。
    @State private var stageTask: Task<Void, Never>?

    /// 内容露出计时任务句柄。
    @State private var revealTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 兜底底色：主题尚未注册时全局背景是全透明的，
                // 没有这一层窗口会是一片空白。
                startupBackdrop
                    .ignoresSafeArea()

                // 背景与主界面完全同源（同一个 chromeTheme + 同一段渐变），
                // 因此加载页切到主界面时不会出现明暗或色相跳变。
                themeRegistry.chromeTheme.makeGlobalBackground(proxy: geometry)
                    .ignoresSafeArea()

                if revealsContent {
                    content
                        .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cisum.kernel.loading")
        .onAppear { startSequence() }
        .onDisappear {
            stageTask?.cancel()
            revealTask?.cancel()
        }
    }

    /// 启动阶段的窗口底色。
    ///
    /// 跟随系统的中性窗口底色：主题目录在内核启动之后才注册，此刻无法
    /// 预知最终配色。用系统底色打底，起点就不会与终点（浅色或深色主题）
    /// 相斥，从加载页切到主界面时不会出现明暗闪烁。
    private var startupBackdrop: Color {
        #if canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #elseif canImport(UIKit)
        Color(uiColor: .systemBackground)
        #else
        theme.background
        #endif
    }

    // MARK: - 内容

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: AppUI.Spacing.xl) {
                brand
                labels
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppUI.Spacing.xl)
    }

    // MARK: - 品牌标记

    private var brand: some View {
        ZStack {
            // 背后的柔光，把标记从背景里托起来。
            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.primary.opacity(colorScheme == .dark ? 0.34 : 0.22), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 90
                    )
                )
                .frame(width: 190, height: 190)
                .blur(radius: 6)

            // 旋转光环：经典加载指示器，但用主题渐变而非灰色，
            // 让「正在工作」这件事与品牌视觉统一。
            progressRing

            CisumBrandMark(size: 104, scheme: colorScheme)
        }
        .frame(width: 190, height: 190)
    }

    /// 围绕品牌标记旋转的渐变光环。
    private var progressRing: some View {
        TimelineView(.animation) { context in
            // 无动画偏好时停在固定角度，避免持续重绘。
            let angle = motionPreference.allowsMotion
                ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4 * 360
                : 0.0

            Circle()
                .trim(from: 0.06, to: 0.94)
                .stroke(
                    AngularGradient(
                        colors: [
                            theme.primary.opacity(0.05),
                            theme.primary.opacity(0.35),
                            theme.primary.opacity(0.95),
                            theme.primarySecondary.opacity(0.9),
                            theme.primary.opacity(0.05)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 168, height: 168)
                .rotationEffect(.degrees(angle))
                .opacity(motionPreference.allowsMotion ? 1 : 0.55)
        }
    }

    // MARK: - 文案

    private var labels: some View {
        VStack(spacing: AppUI.Spacing.sm) {
            Text("Cisum")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textPrimary)

            Text(stage.messageKey)
                .font(AppUI.Typography.caption1)
                .foregroundStyle(theme.textSecondary)
                .contentTransition(.opacity)
                .animation(
                    motionPreference.allowsMotion ? .easeInOut(duration: 0.25) : nil,
                    value: stage
                )
        }
    }

    // MARK: - 时序

    /// 启动内容露出与阶段推进。
    ///
    /// 内容先延迟露出；一旦露出，阶段文案按节奏推进，让等待有内容。
    /// 真正就绪时视图会被替换，两个计时器随之取消。
    private func startSequence() {
        revealTask = Task { @MainActor in
            try? await Task.sleep(for: Self.contentRevealDelay)
            guard !Task.isCancelled else { return }
            revealsContent = true
        }

        stageTask = Task { @MainActor in
            let schedule: [(Stage, Duration)] = [
                (.loadingPlugins, .milliseconds(260)),
                (.preparingInterface, .milliseconds(520))
            ]
            for (next, delay) in schedule {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                stage = next
            }
        }
    }
}

#Preview("Light") {
    KernelLoadingView()
        .frame(width: 400, height: 700)
}

#Preview("Dark") {
    KernelLoadingView()
        .preferredColorScheme(.dark)
        .frame(width: 400, height: 700)
}

import LumiUI
import SwiftUI

/// 音乐库加载骨架屏
/// 模拟音频列表的行布局，带呼吸动画效果，铺满整个内容区域。
///
/// 骨架屏上方常驻一行阶段说明：用户在等待时需要知道后台**具体在做什么**，
/// 而不是只看到一片占位块。等待超过常见时长后，说明会升级为原因解释；
/// 长时间无进展时再给出可操作的排查与重试入口。
struct AudioLibrarySkeletonView: View {
    @LumiTheme private var appTheme
    @State private var isBreathing = false
    @State private var elapsedSeconds = 0

    /// 当前骨架屏对应的真实加载阶段。
    var phase: AudioLibraryLoadingPhase = .openingLibrary
    /// 「重新加载」动作；为 `nil` 时不展示重试按钮。
    var onRetry: (() -> Void)?

    // MARK: - 布局常量

    /// 顶部留白，和 List 的 section header 高度对齐
    nonisolated static let topInset: CGFloat = 28

    /// 单行占位高度：40pt 头像 + 上下各 10pt 内边距
    nonisolated static let rowHeight: CGFloat = 60

    /// 行数上限：避免超高窗口下生成过多占位行（无视觉收益，只增加绘制开销）
    nonisolated static let maximumRowCount = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusHeader

            // 提示区占用的高度由 `GeometryReader` 自动扣除，行数继续按剩余
            // 高度反推，保证骨架总高（提示 + 顶留白 + 行）永不溢出容器。
            GeometryReader { geometry in
                let rowCount = Self.rowCount(forAvailableHeight: geometry.size.height)

                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                        .frame(height: Self.topInset)

                    ForEach(0..<rowCount, id: \.self) { index in
                        skeletonRow(index: index)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .modifier(SkeletonRowTestAnchor(index: index))
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(appTheme.background.ignoresSafeArea())
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.4)
                .repeatForever(autoreverses: true)
            ) {
                isBreathing = true
            }
        }
        // 阶段切换即视为有进展：等待计时从新阶段重新开始。
        .task(id: phase) {
            elapsedSeconds = 0
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                elapsedSeconds += 1
            }
        }
    }

    // MARK: - 阶段提示

    /// 等待等级：决定是否补充原因说明与重试入口。
    private var hintLevel: AudioLibraryLoadingHintLevel {
        AudioLibraryLoadingHintLevel.level(forElapsedSeconds: elapsedSeconds)
    }

    /// 阶段说明：描述后台正在做的那件事，而不是笼统的「加载中」。
    ///
    /// 必须用 `String(localized:bundle:)` 取字符串：`Text(LocalizedStringKey)`
    /// 默认查主 App 的 bundle，而本视图的资源在插件模块里，直接传 Key 会
    /// 回退成英文原文。
    private var phaseMessage: String {
        switch phase {
        case .openingLibrary:
            return String(
                localized: "Opening your music library and reading the list...",
                bundle: .module
            )
        case .syncingRepository:
            return String(
                localized: "Updating the library index with the files in your folder...",
                bundle: .module
            )
        case .reloadingLibrary:
            return String(
                localized: "The library changed. Refreshing the list...",
                bundle: .module
            )
        }
    }

    /// 等待变久后的补充说明；`nil` 表示当前无需额外说明。
    private var secondaryMessage: String? {
        switch hintLevel {
        case .normal:
            return nil
        case .slow:
            return String(
                localized: "This can take longer when the folder has many files or is stored in iCloud.",
                bundle: .module
            )
        case .stalled:
            return String(
                localized: "If nothing changes, check that the repository folder is still accessible, then reload.",
                bundle: .module
            )
        }
    }

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                ProgressView()
                    .controlSize(.small)

                Text(phaseMessage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    // 窄窗口与大字号下换行而不是横向挤压 / 截断。
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let secondaryMessage {
                Text(secondaryMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    // 与文字列左对齐：进度指示器宽度 + 间距。
                    .padding(.leading, 24)
            }

            if hintLevel == .stalled, let onRetry {
                Button(action: onRetry) {
                    Text(String(localized: "Reload", bundle: .module))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.leading, 24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cisum.audio.skeleton.status")
    }

    /// 按可用高度决定骨架行数。
    ///
    /// 早期实现把行数写死为 12（总高 `28 + 12 × 60 = 748pt`），不随内容区高度
    /// 变化。当内容区（窗口高度减去播放控制区）小于 748pt 时，`VStack` 内容溢出，
    /// 在 `ZStack` 里被**居中**放置，整体上移约一半溢出量：顶部几行藏到播放控制区
    /// 底下（表现为「列表上方被遮住」），底部几行超出窗口被裁掉。
    ///
    /// 因此这里必须由可用高度反推行数，且留至少 1 行，保证内容永不溢出容器。
    ///
    /// `nonisolated`：纯计算，不触碰任何 actor 隔离的状态，便于直接单测。
    nonisolated static func rowCount(forAvailableHeight height: CGFloat) -> Int {
        guard height.isFinite, height > topInset else { return 1 }

        let fitting = Int((height - topInset) / rowHeight)
        return min(max(fitting, 1), maximumRowCount)
    }

    private func skeletonRow(index: Int) -> some View {
        HStack(spacing: 12) {
            // 圆形头像占位
            RoundedRectangle(cornerRadius: 20)
                .fill(skeletonColor)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 6) {
                // 标题占位
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonColor)
                    .frame(height: 12)
                    .frame(maxWidth: .infinity)

                // 副标题占位，每行宽度略有差异更自然
                RoundedRectangle(cornerRadius: 3)
                    .fill(skeletonColor)
                    .frame(height: 8)
                    .frame(width: subtitleWidth(for: index))
            }

            Spacer()
        }
    }

    /// 呼吸状态下的骨架颜色
    private var skeletonColor: Color {
        appTheme.surface
            .opacity(isBreathing ? 0.55 : 0.25)
    }

    /// 根据行号返回不同的副标题宽度，模拟真实列表的参差感
    private func subtitleWidth(for index: Int) -> CGFloat {
        let widths: [CGFloat] = [70, 100, 85, 60, 95, 75, 110, 80, 90, 65, 105, 75]
        return widths[index % widths.count]
    }
}

// MARK: - UI test anchor

/// 骨架行的 UI 测试锚点。
///
/// 骨架行没有文本 / 按钮语义，XCUITest 无法定位，只能靠显式标识；又因为外层
/// `AudioDBPluginTabView` 对整个子树挂了 `.accessibilityIdentifier("cisum.scene.music")`，
/// macOS 会把祖先标识下发给没有自己标识的后代——所以单行
/// `.accessibilityIdentifier(...)` 会被覆盖（实测 12 行全部显示同一个 id）。
/// `accessibilityLabel` 不受该覆盖影响，因此这里改用**带行号的 label** 作为锚点。
///
/// 仅在 UI 测试启动（`--cisum-ui-testing-audio-load-delay`）时注入，
/// 生产构建下本修饰符为空操作，不改变无障碍树，也不让 VoiceOver 念出占位文案。
private struct SkeletonRowTestAnchor: ViewModifier {
    let index: Int

    /// 是否处于 UI 测试模式（与加载延迟参数共用同一个开关）。
    private static var isUITesting: Bool {
        AudioLibraryLoadDelayControl.firstPageDelay() != nil
    }

    /// 锚点文案：同时充当 UI 测试的定位键。
    static let rowLabelPrefix = "cisum.audio.skeleton.row."

    func body(content: Content) -> some View {
        if Self.isUITesting {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.label(for: index))
        } else {
            content
        }
    }

    /// 第 `index` 行的锚点文案。
    static func label(for index: Int) -> String {
        "\(rowLabelPrefix)\(index)"
    }
}

// MARK: - Preview

#Preview {
    AudioLibrarySkeletonView()
}

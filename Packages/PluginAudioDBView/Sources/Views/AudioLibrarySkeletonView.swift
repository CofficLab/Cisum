import LumiUI
import SwiftUI

/// 音乐库加载骨架屏
/// 模拟音频列表的行布局，带呼吸动画效果，铺满整个内容区域。
struct AudioLibrarySkeletonView: View {
    @LumiTheme private var appTheme
    @State private var isBreathing = false

    // MARK: - 布局常量

    /// 顶部留白，和 List 的 section header 高度对齐
    nonisolated static let topInset: CGFloat = 28

    /// 单行占位高度：40pt 头像 + 上下各 10pt 内边距
    nonisolated static let rowHeight: CGFloat = 60

    /// 行数上限：避免超高窗口下生成过多占位行（无视觉收益，只增加绘制开销）
    nonisolated static let maximumRowCount = 20

    var body: some View {
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

import LumiUI
import SwiftUI

/// 「⋯」更多按钮 + 空仓库引导气泡。
///
/// 仓库为空时，按钮上方浮出一枚小气泡：圆角胶囊写着一行文案，底下一个尖端
/// 指向按钮本身。气泡挂在真实按钮上，而不是另画一颗「示意按钮」——用户一眼
/// 就能把气泡和眼前那颗按钮对上。
///
/// 按钮同时切到高亮描边（`AppCircularIconButton` 的激活态描边），让「该点这里」
/// 在没有细读文案时也能被察觉。
///
/// 点击行为不变：仍然是展开 / 收起音乐仓库视图。
struct MoreButtonGuidanceView: View {
    @LumiTheme private var appTheme

    /// 按钮直径（与控制按钮组保持一致）。
    let size: CGFloat

    /// 是否展示引导气泡（仓库为空、且仓库视图尚未展开）。
    let showsGuidance: Bool

    /// 按钮动作：展开 / 收起音乐仓库视图。
    let action: () -> Void

    var body: some View {
        AppCircularIconButton(
            systemImage: "ellipsis",
            accessibilityLabel: "More",
            size: size,
            // 引导态借用按钮的激活描边做高亮：这是组件里唯一一处「描边强调」，
            // 与播放按钮的激活态共用同一套视觉语言。
            isActive: showsGuidance,
            action: action
        )
        .overlay(alignment: .bottomLeading) {
            if showsGuidance {
                guidanceCallout
                    .fixedSize()
                    // 气泡下沿落在按钮上沿之上 gap 处：尖端刚好指着按钮。
                    .offset(y: -(size + Self.calloutGap))
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showsGuidance)
    }

    // MARK: - 区块

    /// 引导气泡：胶囊文案 + 指向按钮的三角尖端。
    ///
    /// 气泡**左边缘**与按钮左边缘对齐，而不是居中：控制按钮组里「⋯」是最左边
    /// 一颗，居中会让气泡在窄窗口下溢出屏幕左沿。改为左对齐后，气泡只会向右
    /// 展开，右侧永远是其余四颗按钮的位置。
    private var guidanceCallout: some View {
        VStack(spacing: 0) {
            calloutBody
                .overlay(alignment: .bottomLeading) {
                    // 尖端横移到按钮中心：它是气泡与按钮之间的唯一连接点。
                    PointerTriangle()
                        .fill(DesignTokens.Material.glassUltra)
                        .frame(width: Self.pointerWidth, height: Self.pointerHeight)
                        .offset(
                            x: size / 2 - Self.pointerWidth / 2,
                            y: Self.pointerHeight / 2
                        )
                }

            // 给尖端留出悬在气泡下沿之外的那一半高度。
            Color.clear.frame(height: Self.pointerHeight / 2)
        }
        .accessibilityIdentifier("cisum.player.more.guidance")
    }

    /// 气泡本体：固定宽度的圆角胶囊。
    ///
    /// 宽度固定而不是随文字伸缩：尖端的横向位置由「按钮中心」决定，气泡若
    /// 宽度不定，尖端就得跟着测量结果漂移。定宽之后，尖端永远正对按钮。
    private var calloutBody: some View {
        Text(guidanceText)
            .font(.system(size: 12))
            .foregroundStyle(appTheme.textPrimary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: Self.calloutWidth)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DesignTokens.Material.glassUltra)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(appTheme.textSecondary.opacity(0.14), lineWidth: 1)
            }
            .shadow(
                color: DesignTokens.Shadow.subtle,
                radius: 6,
                y: 2
            )
    }

    /// 气泡文案。
    private var guidanceText: String {
        String(localized: "Music repository is empty. Tap here to add music.", bundle: .module)
    }

    // MARK: - 度量

    /// 气泡与按钮上沿之间的间隙。
    private static let calloutGap: CGFloat = 6

    /// 气泡宽度。
    private static let calloutWidth: CGFloat = 220

    /// 尖端三角形的宽 / 高。
    private static let pointerWidth: CGFloat = 10
    private static let pointerHeight: CGFloat = 6
}

/// 指向下方的等腰三角形：尖端在底边中点。
private struct PointerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 预览

#Preview("More Button Guidance") {
    VStack(spacing: 60) {
        HStack(spacing: 40) {
            MoreButtonGuidanceView(size: 44, showsGuidance: false) {}
            MoreButtonGuidanceView(size: 44, showsGuidance: true) {}
        }

        HStack(spacing: 40) {
            MoreButtonGuidanceView(size: 32, showsGuidance: true) {}
            MoreButtonGuidanceView(size: 72, showsGuidance: true) {}
        }
    }
    .padding(80)
    .background(Color.orange)
}

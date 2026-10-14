import LumiUI
import SwiftUI

/// 音乐库加载骨架屏
/// 模拟音频列表的行布局，带呼吸动画效果，铺满整个内容区域。
struct AudioLibrarySkeletonView: View {
    @LumiTheme private var appTheme
    @State private var isBreathing = false

    /// 骨架行数量，足够撑满常规屏幕高度
    private let rowCount = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部留白，和 List 的 section header 高度对齐
            Spacer()
                .frame(height: 28)

            ForEach(0..<rowCount, id: \.self) { index in
                skeletonRow(index: index)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }

            Spacer()
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

// MARK: - Preview

#Preview {
    AudioLibrarySkeletonView()
}

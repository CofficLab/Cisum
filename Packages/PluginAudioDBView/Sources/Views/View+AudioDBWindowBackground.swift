import SwiftUI

/// 库区窗口底色。
///
/// visionOS 的窗口自带系统玻璃底板，整块铺实心主题底色会把窗口切成
/// 「上方玻璃、下方板材」两截，打断与 hero 区的视觉连续性（系统应用的
/// 标准做法是让内容直接坐在玻璃上），因此 visionOS 上保持透明，行的
/// hover / 选中反馈仍由行自身的主题背景提供；其余平台没有玻璃底板，
/// 仍需主题底色打底。
extension View {
    @ViewBuilder
    func audioDBWindowBackground(_ color: Color) -> some View {
        #if os(visionOS)
        background(Color.clear)
        #else
        background(color.ignoresSafeArea())
        #endif
    }
}

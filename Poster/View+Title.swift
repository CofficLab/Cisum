import MagicKit
import SwiftUI

// MARK: - Poster Title Styles

extension View {
    /// 将文本样式化为 Mac 版海报标题样式
    ///
    /// 使用超大号圆体字（200pt），加粗显示，带有底部间距和轻微阴影效果。
    /// 适用于 App Store 截图中的 Mac 版海报主标题。
    ///
    /// - Returns: 应用了标题样式的视图
    func asPosterTitle() -> some View {
        self.bold()
            .font(.system(size: 200, design: .rounded))
            .padding(.bottom, 40)
            .shadowSm()
    }

    /// 将文本样式化为 Mac 版海报副标题样式
    ///
    /// 使用中等大小圆体字（100pt），次要颜色显示，带有轻微阴影效果。
    /// 适用于 App Store 截图中的 Mac 版海报副标题或描述文字。
    ///
    /// - Returns: 应用了副标题样式的视图
    func asPosterSubTitle() -> some View {
        self.font(.system(size: 100, design: .rounded))
            .foregroundStyle(.secondary)
            .shadowSm()
    }
    
    /// 将文本样式化为 iPhone 版海报标题样式
    ///
    /// 使用大号圆体字（150pt），加粗显示，带有底部间距和轻微阴影效果。
    /// 适用于 App Store 截图中的 iPhone 版海报主标题。
    ///
    /// - Returns: 应用了标题样式的视图
    func asPosterTitleForIPhone() -> some View {
        self.bold()
            .font(.system(size: 160, design: .rounded))
            .padding(.bottom, 40)
            .shadowSm()
    }

    /// 将文本样式化为 iPhone 版海报副标题样式
    ///
    /// 使用中号圆体字（80pt），次要颜色显示，带有轻微阴影效果。
    /// 适用于 App Store 截图中的 iPhone 版海报副标题或描述文字。
    ///
    /// - Returns: 应用了副标题样式的视图
    func asPosterSubTitleForIPhone() -> some View {
        self.font(.system(size: 100, design: .rounded))
            .foregroundStyle(.secondary)
            .shadowSm()
    }
}

// MARK: - Preview

#Preview("App Store Hero") {
    AppStoreHero()
        .inMagicContainer(.macBook13, scale: 0.5)
}

#Preview("App Store iOS - Hero - iPhone 5.5") {
    iPhoneHero()
        .inMagicContainer(.iPhone55, scale: 0.45)
}

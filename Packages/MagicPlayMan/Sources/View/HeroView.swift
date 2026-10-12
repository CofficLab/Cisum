import CisumUIComponents
import LumiUI
import MagicKit
import OSLog
import SwiftUI

/// 英雄视图 - 显示媒体资源的封面图
///
/// 封装 AvatarView 并正确处理 URL 变化，确保切换歌曲时
/// 封面图立即更新。
struct HeroView: View, SuperLog {
    nonisolated static let emoji = "🖼️"

    let url: URL
    let verbose: Bool
    let preferredSize: CGFloat // 首选尺寸
    let avatarShape: AvatarViewShape? // Avatar 形状

    init(
        url: URL,
        verbose: Bool = false,
        preferredSize: CGFloat = 512,
        avatarShape: AvatarViewShape? = nil
    ) {
        self.url = url
        self.verbose = verbose
        self.preferredSize = preferredSize
        self.avatarShape = avatarShape
    }

    var body: some View {
        GeometryReader { geo in
            let availableSize = min(geo.size.width, geo.size.height)
            let padding: CGFloat = 40
            let size = availableSize - padding

            let avatarView = url.makeAvatarView(verbose: verbose)
                .magicSize(size)

            Group {
                if let shape = avatarShape {
                    avatarView.magicAvatarShape(shape)
                } else {
                    avatarView.magicAvatarShape(.roundedRectangle(cornerRadius: 12))
                }
            }
            .frame(width: size, height: size)
            .id(url) // 关键：强制在 URL 改变时重建视图
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

#if false
#Preview("HeroView") {
    HeroView(url: .sample_web_mp3_kennedy)
        .frame(width: 400, height: 400)
}

#Preview("HeroView") {
    HeroView(url: .sample_temp_jpg)
        .frame(width: 400, height: 400)
}
#endif

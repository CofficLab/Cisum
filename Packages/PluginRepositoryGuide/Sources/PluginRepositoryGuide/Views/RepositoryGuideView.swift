import LumiUI
import SwiftUI

/// 空仓库引导面板。
///
/// 呈现时机：仓库为空、且仓库视图收起（控制区占满窗口）时，出现在窗口顶部
/// 主要区域——也就是真实播放器里封面与标题待着的那一块。
///
/// 面板**照着真实播放界面排**：封面位放 app 自己的图标，标题位写「开始使用
/// Cisum」，其余留白照旧。这样用户看到的就是「播放器的样子」，而不是一块
/// 突兀的说明卡片。顶部的空荡也因此有了着落——没有音乐时，播放器本来是空的。
///
/// **刻意不教「点⋯」**：仓库视图在哪里打开，由「⋯」按钮自己提示（见
/// `PluginAudioControlButtons.MoreButtonGuidanceView`）。这里再画一颗示意
/// 按钮加一句「点下方的⋯」，等于让用户对着两个入口发愣。
struct RepositoryGuideView: View {
    @LumiTheme private var appTheme

    /// 封面图：默认取宿主 app 图标；测试可注入固定图片。
    private let iconOverride: Image?

    /// 标题区高度：与真实播放器一致（`PlaybackHeroView.titleViewHeight`）。
    private let titleViewHeight: CGFloat = 60

    init(iconOverride: Image? = nil) {
        self.iconOverride = iconOverride
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // 封面 + 标题作为一组居中：和真实播放器「图在上、名字在下」的
                // 构图一致，而不是把图钉在顶上、名字掉在很下面。
                VStack(spacing: 0) {
                    coverArea(in: geometry)
                    titleArea(in: geometry)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 区块

    /// 封面位：真实播放器这里放专辑图，这里换成 app 图标。
    private func coverArea(in geometry: GeometryProxy) -> some View {
        let available = max(0, geometry.size.height - titleViewHeight)
        let side = max(0, min(geometry.size.width - 64, available - 24))

        return coverImage
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadowXxxl()
            // 只撑宽、不撑高：高度留给外层 Spacer 去分配，标题才紧贴在图标下面。
            .frame(maxWidth: .infinity)
    }

    /// app 图标；取不到时回退到 SF Symbol 占位，保证永远有东西可看。
    @ViewBuilder
    private var coverImage: some View {
        if let icon = iconOverride ?? HostAppIcon.image() {
            icon.resizable().aspectRatio(contentMode: .fit)
        } else {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(appTheme.surface.opacity(0.72))
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(appTheme.primary)
                }
        }
    }

    /// 标题位：真实播放器这里是曲目名，这里写「开始使用 Cisum」。
    private func titleArea(in geometry: GeometryProxy) -> some View {
        Text(String(localized: "Start using Cisum", bundle: .module))
            .font(.system(size: 24))
            .lineLimit(2)
            .minimumScaleFactor(0.3)
            .multilineTextAlignment(.center)
            .frame(width: max(0, geometry.size.width - 32))
            .frame(height: titleViewHeight)
            .foregroundStyle(appTheme.textPrimary)
            .shadow(color: appTheme.background.opacity(0.18), radius: 8, y: 2)
            .accessibilityIdentifier("cisum.repository.guide.title")
    }
}

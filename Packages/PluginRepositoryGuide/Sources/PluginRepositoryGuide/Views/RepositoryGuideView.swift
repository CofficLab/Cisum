import LumiUI
import SwiftUI

/// 空仓库引导面板。
///
/// 呈现时机：仓库为空、且仓库视图收起（控制区占满窗口）时，出现在窗口顶部
/// 主要区域——也就是真实播放器里封面与标题待着的那一块。
///
/// 面板**照着真实播放界面排**：封面位放 app 自己的图标，标题位写「开始使用
/// Cisum」，其余留白照旧。这样用户看到的就是「播放器的样子」，而不是一块
/// 突兀的说明卡片。
///
/// 底部再指一下控制按钮组最左边那颗「⋯」——它就是展开/收起仓库视图的开关，
/// 引导面板正好贴在它上方。
///
/// **刻意不提示拖放**：拖放是仓库视图的能力。在引导里教「把文件拖进来」，
/// 会让用户以为引导面板能接文件，反而不知道真正的拖放入口在仓库视图里。
struct RepositoryGuideView: View {
    @LumiTheme private var appTheme

    /// 封面图：默认取宿主 app 图标；测试可注入固定图片。
    private let iconOverride: Image?

    /// 标题区高度：与真实播放器一致（`PlaybackHeroView.titleViewHeight`）。
    private let titleViewHeight: CGFloat = 60

    /// 底部指向区高度：箭头 + 「⋯」示意 + 一行说明。
    private let hintHeight: CGFloat = 96

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

                hintArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 区块

    /// 封面位：真实播放器这里放专辑图，这里换成 app 图标。
    private func coverArea(in geometry: GeometryProxy) -> some View {
        let available = max(0, geometry.size.height - titleViewHeight - hintHeight)
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

    /// 指向控制按钮组里的「⋯」按钮——它按下就会展开仓库视图。
    private var hintArea: some View {
        VStack(spacing: 10) {
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(appTheme.textTertiary)

            // 和控制按钮组里那颗「⋯」长得一模一样，方便用户一眼对上。
            Image(systemName: "ellipsis")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(appTheme.textSecondary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(DesignTokens.Material.glassUltra))
                .overlay(
                    Circle()
                        .stroke(appTheme.textSecondary.opacity(0.12), lineWidth: 1)
                )
                .shadow(
                    color: DesignTokens.Shadow.subtle,
                    radius: 4,
                    y: 1
                )

            Text(String(localized: "Tap the ⋯ button below to open the repository", bundle: .module))
                .font(.system(size: 13))
                .foregroundStyle(appTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: hintHeight)
        .accessibilityIdentifier("cisum.repository.guide.hint")
    }
}

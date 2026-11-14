import LumiUI
import SwiftUI

/// 播放器控制区封面/标题视图。
///
/// 复刻原 ControlView 默认 HeroView 的行为：右侧封面栏可见（宽度 > 768）或
/// 高度不足时只显示标题，否则显示主封面与标题。
struct PlaybackHeroView: View {
    @ObservedObject private var viewModel: PlaybackHeroViewModel
    @LumiTheme private var appTheme
    @LumiMotionPreferenceReader private var motionPreference

    private let titleViewHeight: CGFloat = 60
    private let isDemoMode: Bool

    init(viewModel: PlaybackHeroViewModel, isDemoMode: Bool) {
        self.viewModel = viewModel
        self.isDemoMode = isDemoMode
    }

    private var title: String {
        viewModel.currentURL?.deletingPathExtension().lastPathComponent ?? ""
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if viewModel.isHeroVisible, shouldShowAlbum(in: geometry) {
                    if viewModel.state.isDownloading {
                        downloadingAlbumView
                            .frame(maxWidth: .infinity)
                            .frame(height: albumHeight(in: geometry))
                            .clipped()
                    } else if isDemoMode {
                        demoAlbumView
                            .frame(maxWidth: .infinity)
                            .frame(height: albumHeight(in: geometry))
                    } else {
                        viewModel.makeMediaView()
                            .frame(maxWidth: .infinity)
                            .frame(height: albumHeight(in: geometry))
                    }
                } else if viewModel.showsIdlePlaceholder, shouldShowAlbum(in: geometry) {
                    // 「无当前曲目」占位：仓库里有歌但用户还没选。
                    // 真实封面缺席时这块区域本会整片空白，占位接手它。
                    idlePlaceholderAlbumView
                        .frame(maxWidth: .infinity)
                        .frame(height: albumHeight(in: geometry))
                }

                if viewModel.isHeroVisible {
                    Text(title)
                        .font(.system(size: 24))
                        .accessibilityIdentifier("cisum.player.title")
                        .lineLimit(2)
                        .minimumScaleFactor(0.3)
                        .multilineTextAlignment(.center)
                        .frame(width: max(0, geometry.size.width - 32))
                        .frame(height: titleViewHeight)
                        .foregroundStyle(appTheme.textPrimary)
                        .shadow(color: appTheme.background.opacity(0.18), radius: 8, y: 2)

                    // 标题下方**不再**渲染下载状态行：引擎的 `localizedStateText()`
                    // 在下载态下已自带百分比（如「正在下载 0%」），这里再拼一次
                    // 前缀就会显示成「0% 正在下载 0%」——同一行两个百分比。
                    // 下载进度改由封面区的大圆环（cisum.player.download.overlay）独占
                    // 呈现；该圆环仅在控制区高度 > 450pt 时渲染。
                } else if viewModel.showsIdlePlaceholder {
                    // 占位态的提示文案：占据真实播放器里「曲目标题」的位置，
                    // 让这一屏看起来仍像一个播放器，而不是一块说明卡片。
                    Text(Self.idlePlaceholderText)
                        .font(.system(size: 24))
                        .accessibilityIdentifier("cisum.player.idle.placeholder")
                        .lineLimit(2)
                        .minimumScaleFactor(0.3)
                        .multilineTextAlignment(.center)
                        .frame(width: max(0, geometry.size.width - 32))
                        .frame(height: titleViewHeight)
                        .foregroundStyle(appTheme.textPrimary)
                        .shadow(color: appTheme.background.opacity(0.18), radius: 8, y: 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 占位态的提示文案。
    ///
    /// 与空仓库引导的「开始使用 Cisum」区分开：那是**仓库空**时的引导，
    /// 这里说的是**仓库有歌但还没选**——用户该去仓库挑一首。
    private static let idlePlaceholderText = String(
        localized: "Pick a track to start playing",
        bundle: .module
    )

    private func shouldShowAlbum(in geometry: GeometryProxy) -> Bool {
        !AppResponsivePlayerLayoutMetrics.shared.shouldShowSecondaryColumn(width: geometry.size.width)
            && geometry.size.height > AppResponsivePlayerLayoutMetrics.shared.secondaryColumnMinimumHeight
    }

    private func albumHeight(in geometry: GeometryProxy) -> CGFloat {
        max(0, geometry.size.height - titleViewHeight)
    }

    private var demoAlbumView: some View {
        Image.coffeeReelIcon(useDefaultBackground: false, handleRotation: 0)
            .shadowXxxl()
    }

    /// 占位态的封面：品牌图（咖啡滤杯）。
    ///
    /// 用 `useDefaultBackground: true` 让品牌渐变底色一并显示——这是本插件
    /// 自己的品牌资产（`CoffeeReelIcon`），纯代码绘制、任意尺寸都清晰，
    /// 与空仓库引导用宿主 app 图标不同：占位态表达的是「播放器还没东西可放」，
    /// 用品牌图形比用 app 图标更贴近「这是一个播放器」这件事。
    private var idlePlaceholderAlbumView: some View {
        Image.coffeeReelIcon(useDefaultBackground: true, handleRotation: 0)
            .shadowXxxl()
    }

    private var downloadingAlbumView: some View {
        ZStack {
            Circle()
                .stroke(appTheme.textTertiary.opacity(0.18), lineWidth: 8)
                .frame(width: 200, height: 200)

            Circle()
                .trim(from: 0, to: downloadProgress)
                .stroke(
                    appTheme.primary,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(
                    LumiMotion.enabled(.easeInOut(duration: 0.2), preference: motionPreference),
                    value: downloadProgress
                )

            VStack(spacing: 8) {
                Text("\(Int(downloadProgress * 100))%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(appTheme.textPrimary)
                    .accessibilityIdentifier("cisum.player.download.progress")
                // 底部小字只写「正在下载」：圆环中心已单独显示百分比，
                // 这里再带百分比就会同一屏出现两个百分比
                // （历史上曾拼成「0% 正在下载 0%」）。
                Text(viewModel.localizedDownloadingLabel())
                    .font(.system(size: 14))
                    .foregroundStyle(appTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("cisum.player.download.state")
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appTheme.elevatedSurface.opacity(0.55))
        .accessibilityIdentifier("cisum.player.download.overlay")
    }

    private var downloadProgress: CGFloat {
        guard case let .loading(.downloading(progress)) = viewModel.state else { return 0 }
        return CGFloat(min(max(progress.isFinite ? progress : 0, 0), 1))
    }
}

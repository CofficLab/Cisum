import CisumUIComponents
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
                if shouldShowAlbum(in: geometry) {
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
                }

                Text(title)
                    .font(.system(size: 24))
                    .lineLimit(2)
                    .minimumScaleFactor(0.3)
                    .multilineTextAlignment(.center)
                    .frame(width: max(0, geometry.size.width - 32))
                    .frame(height: titleViewHeight)
                    .foregroundStyle(appTheme.textPrimary)
                    .shadow(color: appTheme.background.opacity(0.18), radius: 8, y: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        #if os(macOS)
            .ignoresSafeArea(edges: .horizontal)
        #else
            .ignoresSafeArea()
        #endif
    }

    private func shouldShowAlbum(in geometry: GeometryProxy) -> Bool {
        !CisumPlayerLayout.shouldShowRightAlbum(width: geometry.size.width)
            && geometry.size.height > CisumPlayerLayout.albumMinimumHeight
    }

    private func albumHeight(in geometry: GeometryProxy) -> CGFloat {
        max(0, geometry.size.height - titleViewHeight)
    }

    private var demoAlbumView: some View {
        Image.cisumCoffeeReelIcon(useDefaultBackground: false, handleRotation: 0)
            .cisumShadow3xl()
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
                Text(viewModel.localizedStateText())
                    .font(.system(size: 14))
                    .foregroundStyle(appTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appTheme.elevatedSurface.opacity(0.55))
    }

    private var downloadProgress: CGFloat {
        guard case let .loading(.downloading(progress)) = viewModel.state else { return 0 }
        return CGFloat(min(max(progress.isFinite ? progress : 0, 0), 1))
    }
}

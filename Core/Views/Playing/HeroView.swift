import MagicKit
import OSLog
import SwiftUI

struct HeroView: View, SuperLog {
    nonisolated static let emoji = "🎭"
    nonisolated static let verbose = false

    @EnvironmentObject var app: AppProvider
    @EnvironmentObject var playMan: PlayMan
    @Environment(\.demoMode) var isDemoMode
    @Environment(\.downloadingMode) var isDownloadingMode

    private let titleViewHeight: CGFloat = 60

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                if shouldShowAlbum(geo) {
                    if isDownloadingMode {
                        // 下载中场景: 显示圆形进度
                        downloadingAlbumView
                            .frame(maxWidth: .infinity)
                            .frame(height: getAlbumHeight(geo))
                            .clipped()
                    } else if isDemoMode {
                        // Demo mode: 显示静态演示封面
                        demoAlbumView
                            .frame(maxWidth: .infinity)
                            .frame(height: getAlbumHeight(geo))
                            .clipped()
                    } else {
                        playMan.makeHeroView(verbose: Self.verbose, avatarShape: .roundedRectangle(cornerRadius: 8))
                            .frame(maxWidth: .infinity)
                            .frame(height: getAlbumHeight(geo))
                    }
                }

                TitleView()
                    .frame(maxWidth: .infinity)
                    .frame(height: titleViewHeight)
            }
            .infinite()
        }
        .ignoresSafeArea(edges: Config.isDesktop ? .horizontal : .all)
    }
}

// MARK: - View

extension HeroView {
    // 下载中场景的圆形进度视图
    private var downloadingAlbumView: some View {
        ZStack {
            // 背景圆形
            Circle()
                .stroke(
                    Color.secondary.opacity(0.2),
                    lineWidth: 8
                )
                .frame(width: 200, height: 200)

            // 进度圆形（50%）
            Circle()
                .trim(from: 0, to: 0.5)
                .stroke(
                    Color.blue,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: 0.5)

            // 中心文字
            VStack(spacing: 8) {
                Text("50%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("正在从 iCloud 下载")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.1))
    }

    // Demo mode 的静态演示封面
    private var demoAlbumView: some View {
        LogoView(
            background: .white.opacity(0.3),
            backgroundShape: .circle
        )
    }
}

// MARK: - Private Helpers

extension HeroView {
    // 计算专辑封面高度
    private func getAlbumHeight(_ geo: GeometryProxy) -> CGFloat {
        // 总高度减去标题高度就是封面可用空间
        return max(0, geo.size.height - titleViewHeight)
    }

    private func shouldShowAlbum(_ geo: GeometryProxy) -> Bool {
        !app.rightAlbumVisible && geo.size.height > Config.minHeightToShowAlbum
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

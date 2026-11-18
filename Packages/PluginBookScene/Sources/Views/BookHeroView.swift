import LumiUI
import SwiftUI

/// 有声书控制区封面/标题视图。
///
/// 与音乐场景的封面区分开实现：主语是「书 + 章节」，封面来自书库；
/// 宽窗口（>768）或高度不足时只显示书名与章节。
struct BookHeroView: View {
    @ObservedObject private var viewModel: BookHeroViewModel
    @LumiTheme private var appTheme

    private let titleViewHeight: CGFloat = 60

    init(viewModel: BookHeroViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if shouldShowAlbum(in: geometry) {
                    albumView(in: geometry)
                        .frame(maxWidth: .infinity)
                        .frame(height: albumHeight(in: geometry))
                }

                if let subject = viewModel.subject {
                    VStack(spacing: 2) {
                        Text(subject.bookTitle)
                            .font(.system(size: 24))
                            .accessibilityIdentifier("cisum.player.book.title")
                            .lineLimit(2)
                            .minimumScaleFactor(0.3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(appTheme.textPrimary)
                            .shadow(color: appTheme.background.opacity(0.18), radius: 8, y: 2)

                        if let chapterTitle = subject.chapterTitle {
                            Text(chapterTitle)
                                .font(.system(size: 12))
                                .accessibilityIdentifier("cisum.player.book.chapter")
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .foregroundStyle(appTheme.textSecondary)
                        }
                    }
                    .frame(width: max(0, geometry.size.width - 32))
                    .frame(height: titleViewHeight)
                } else if viewModel.showsIdlePlaceholder {
                    Text(Self.idlePlaceholderText)
                        .font(.system(size: 24))
                        .accessibilityIdentifier("cisum.player.book.idle.placeholder")
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

    private static let idlePlaceholderText = String(
        localized: "Pick an audiobook to start listening",
        bundle: .module
    )

    private func shouldShowAlbum(in geometry: GeometryProxy) -> Bool {
        !AppResponsivePlayerLayoutMetrics.shared.shouldShowSecondaryColumn(width: geometry.size.width)
            && geometry.size.height > AppResponsivePlayerLayoutMetrics.shared.secondaryColumnMinimumHeight
    }

    private func albumHeight(in geometry: GeometryProxy) -> CGFloat {
        max(0, geometry.size.height - titleViewHeight)
    }

    private func albumView(in geometry: GeometryProxy) -> some View {
        let side = min(
            max(0, geometry.size.width - 32),
            max(0, geometry.size.height - titleViewHeight)
        )
        return artwork
            .frame(width: side, height: side)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }

    @ViewBuilder
    private var artwork: some View {
        if let cover = viewModel.cover {
            cover
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [appTheme.primary.opacity(0.85), appTheme.primary.opacity(0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "book.closed")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }
}

import LumiUI
import SwiftUI

/// 有声书控制区右侧封面视图；状态来自 `BookHeroViewModel`，不依赖播放引擎。
struct BookHeroRightAlbumView: View {
    @ObservedObject private var viewModel: BookHeroViewModel
    @LumiTheme private var appTheme

    init(viewModel: BookHeroViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Group {
            if viewModel.isHeroVisible || viewModel.showsIdlePlaceholder {
                artwork
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                    .accessibilityIdentifier("cisum.player.book.rightAlbum")
            }
        }
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

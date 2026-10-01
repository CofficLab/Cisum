import CisumUIComponents
import LumiUI
import MagicKit
import OSLog
import SwiftUI

struct AudioPlayerView: View, SuperLog {
    nonisolated static let emoji = "🖥️"

    let title: String
    let artist: String?
    let url: URL?
    let defaultArtwork: Image?
    let defaultArtworkBuilder: (() -> any View)?

    init(title: String, artist: String? = nil, url: URL? = nil, defaultArtwork: Image? = nil, defaultArtworkBuilder: (() -> any View)? = nil) {
        self.title = title
        self.artist = artist
        self.url = url
        self.defaultArtwork = defaultArtwork
        self.defaultArtworkBuilder = defaultArtworkBuilder
    }

    var body: some View {
        VStack(spacing: 20) {
            artworkView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(20)

            // 标题和艺术家
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                if let artist = artist {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private var artworkView: some View {
        if let url {
            url.makeAvatarView()
                .id(url)  // Force view refresh on URL change
        } else if let defaultArtworkBuilder {
            AnyView(defaultArtworkBuilder())
        } else if let defaultArtwork {
            defaultArtwork
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "music.note")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("AudioPlayerView Showcase") {
    AudioPlayerViewShowcase()
}

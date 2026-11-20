import AVFoundation
import ProviderVideo
import SwiftUI

/// 视频网格单元：缩略图 + 标题 + 时长/评分/标签标记。
struct VideoGridCell: View {
    let item: VideoItem
    let isCurrent: Bool
    let onTap: () -> Void

    @State private var thumbnail: PlatformImage?

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                poster
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 4) {
                        Text(item.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        if item.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                        if let rating = item.rating {
                            HStack(spacing: 1) {
                                Image(systemName: rating.symbolText)
                                    .font(.caption2)
                                Text("\(rating.value)")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .task(id: item.url) { await loadThumbnail() }
    }

    private var poster: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.12))
            if let thumbnail {
                thumbnailImage(thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "film")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }

            VStack {
                HStack {
                    Spacer()
                    badges
                }
                Spacer()
                if let duration = item.duration, duration > 0 {
                    Text(item.formattedDuration)
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(.white)
                        .padding(4)
                        .frame(maxWidth: .infinity, alignment: .bottomTrailing)
                }
            }
            .padding(4)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrent ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var badges: some View {
        HStack(spacing: 4) {
            if item.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
            switch item.availability {
            case .cloudNotDownloaded:
                Image(systemName: "icloud.and.arrow.down")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(.black.opacity(0.6), in: Circle())
            case .cloudDownloading:
                Image(systemName: "icloud.and.arrow.up")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(.black.opacity(0.6), in: Circle())
            case .unavailable:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(3)
                    .background(.black.opacity(0.6), in: Circle())
            case .available:
                EmptyView()
            }
        }
    }

    private func loadThumbnail() async {
        let image = await VideoThumbnailService.shared.thumbnail(for: item.url, size: CGSize(width: 320, height: 180))
        thumbnail = image
    }

    @ViewBuilder
    private func thumbnailImage(_ image: PlatformImage) -> Image {
        #if os(macOS)
        Image(nsImage: image)
        #else
        Image(uiImage: image)
        #endif
    }
}

#if os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = UIImage
#endif

import AVFoundation
import ProviderVideo
import SwiftUI

/// 16:9 视频缩略图：按需生成并缓存，未就绪时显示占位。
struct VideoThumbnailView: View {
    let url: URL
    var size = CGSize(width: 320, height: 180)
    var cornerRadius: CGFloat = 8

    @State private var thumbnail: PlatformImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.secondary.opacity(0.12))
            if let thumbnail {
                thumbnailImage(thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "film")
                    .font(.system(size: min(size.width, size.height) * 0.14))
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: url) {
            thumbnail = await VideoThumbnailService.shared.thumbnail(for: url, size: size)
        }
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

/// 可用性角标：iCloud 未下载 / 下载中 / 文件缺失 / 收藏。
struct VideoAvailabilityBadge: View {
    let item: VideoItem

    var body: some View {
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
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white)
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
}

#if os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = UIImage
#endif

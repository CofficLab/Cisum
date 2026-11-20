import AVFoundation
import ProviderVideo
import SwiftUI

/// 视频网格单元：缩略图 + 标题 + 评分 / 标签 + 悬停操作条。
///
/// macOS 上悬停浮出操作条（播放 / 收藏 / 更多），iOS 没有悬停态，操作由
/// 长按菜单与详情面板承担。
struct VideoGridCell: View {
    let item: VideoItem
    let isCurrent: Bool
    let onPlay: () -> Void
    let onFavorite: () -> Void
    let onOpen: () -> Void

    @State private var thumbnail: PlatformImage?
    #if os(macOS)
    @State private var isHovering = false
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            poster
                .onTapGesture(perform: onPlay)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(item.tags.first ?? " ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onPlay)
        }
        .accessibilityIdentifier("cisum.video.item.\(item.url.lastPathComponent)")
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
                HStack(alignment: .bottom) {
                    if item.isInProgress {
                        Image(systemName: "play.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(.black.opacity(0.6), in: Circle())
                    }
                    Spacer()
                    if let duration = item.duration, duration > 0 {
                        Text(item.formattedDuration)
                            .font(.caption2.monospacedDigit())
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 3))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(4)

            if item.isInProgress {
                VStack {
                    Spacer()
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(.black.opacity(0.5))
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: proxy.size.width * item.progress.fraction)
                        }
                    }
                    .frame(height: 3)
                }
            }

            #if os(macOS)
            hoverBar
            #endif
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrent ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        #if os(macOS)
        .onHover { isHovering = $0 }
        #endif
    }

    #if os(macOS)
    private var hoverBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Button(action: onPlay) {
                    Image(systemName: item.availability == .cloudNotDownloaded ? "icloud.and.arrow.down" : "play.fill")
                }
                .accessibilityLabel(
                    item.availability == .cloudNotDownloaded
                        ? String(localized: "Download", bundle: .module)
                        : String(localized: "Play", bundle: .module)
                )
                .disabled(item.availability != .available && item.availability != .cloudNotDownloaded)

                Button(action: onFavorite) {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                }
                .accessibilityLabel(String(localized: "Favorites", bundle: .module))

                Button(action: onOpen) {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel(String(localized: "Edit Tags and Name", bundle: .module))
            }
            .controlSize(.small)
            .buttonStyle(.borderless)
            .padding(8)
        }
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )
        )
        .opacity(isHovering || isCurrent ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.easeOut(duration: 0.15), value: isCurrent)
    }
    #endif

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

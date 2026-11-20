import ProviderVideo
import SwiftUI

/// 视频列表行：缩略图、标题、一个次要信息、时长与下载状态。
struct VideoListRow: View {
    let item: VideoItem
    let isCurrent: Bool
    let onPlay: () -> Void
    let onOpen: () -> Void

    @State private var thumbnailImage: PlatformImage?

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(secondaryTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let duration = item.duration, duration > 0 {
                Text(item.formattedDuration)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            statusBadge
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityIdentifier("cisum.video.item.\(item.url.lastPathComponent)")
        .onTapGesture(perform: onPlay)
        .contextMenu {
            Button {
                onOpen()
            } label: {
                Label(String(localized: "Edit Tags and Name", bundle: .module), systemImage: "pencil")
            }
        }
        .task(id: item.url) {
            thumbnailImage = await VideoThumbnailService.shared.thumbnail(
                for: item.url,
                size: CGSize(width: 160, height: 90)
            )
        }
    }

    private var secondaryTitle: String {
        if item.isInProgress {
            return String(
                format: String(localized: "%lld%% watched", bundle: .module),
                Int64(item.progress.fraction * 100)
            )
        }
        return item.tags.first ?? item.formattedSize
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
            if let thumbnailImage {
                #if os(macOS)
                Image(nsImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                #else
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                #endif
            } else {
                Image(systemName: "film")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            if isCurrent {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .frame(width: 80, height: 45)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch item.availability {
        case .available:
            EmptyView()
        case .cloudNotDownloaded:
            Image(systemName: "icloud.and.arrow.down")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel(String(localized: "In iCloud", bundle: .module))
        case .cloudDownloading:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel(String(localized: "Downloading", bundle: .module))
        case .unavailable:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}

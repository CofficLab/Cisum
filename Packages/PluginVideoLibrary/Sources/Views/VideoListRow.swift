import ProviderVideo
import SwiftUI

/// 视频列表行：缩略图 + 标题 + 标签 + 时长 + 大小 + 状态。
struct VideoListRow: View {
    let item: VideoItem
    let isCurrent: Bool
    let onPlay: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !item.tags.isEmpty {
                        Text(item.tags.prefix(3).joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    }
                    if item.isInProgress {
                        Text(String(
                            format: String(localized: "%lld%% watched", bundle: .module),
                            Int64(item.progress.fraction * 100)
                        ))
                        .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }

            Spacer(minLength: 8)

            if let rating = item.rating {
                Text(rating.symbolText)
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }

            Text(item.formattedDuration)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)

            Text(item.formattedSize)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .trailing)

            statusBadge
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onPlay)
        .contextMenu {
            Button {
                onOpen()
            } label: {
                Label(String(localized: "Edit Tags and Name", bundle: .module), systemImage: "pencil")
            }
        }
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
            Image(systemName: "film")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            if isCurrent {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .frame(width: 96, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch item.availability {
        case .available:
            EmptyView()
        case .cloudNotDownloaded:
            Label {
                Text(String(localized: "In iCloud", bundle: .module))
            } icon: {
                Image(systemName: "icloud.and.arrow.down")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        case .cloudDownloading:
            Label {
                Text(String(localized: "Downloading", bundle: .module))
            } icon: {
                Image(systemName: "arrow.down.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        case .unavailable:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}

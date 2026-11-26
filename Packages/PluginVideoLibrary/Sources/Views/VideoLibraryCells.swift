import ProviderVideo
import SwiftUI

/// 「继续观看」横栏卡片：断点、时长、观看比例一屏可读。
struct VideoContinueRailCard: View {
    let item: VideoItem
    let isCurrent: Bool
    let isSelected: Bool
    let onOpen: () -> Void
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VideoThumbnailView(url: item.url)
                .overlay(alignment: .bottomLeading) {
                    if let resume = item.resumePosition {
                        Label(VideoTimeFormatting.string(from: resume), systemImage: "play.fill")
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(.black)
                            .padding(5)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Text(item.formattedDuration)
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.white)
                        .padding(5)
                }
                .overlay(alignment: .topTrailing) {
                    VideoAvailabilityBadge(item: item)
                        .padding(6)
                }
                .overlay(alignment: .bottom) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(.white.opacity(0.25))
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: proxy.size.width * item.progress.fraction)
                        }
                    }
                    .frame(height: 3)
                }

            Text(item.title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
            HStack {
                if let lastPlayed = item.progress.lastPlayedAt {
                    Text(String(
                        format: String(localized: "Last played %@", bundle: .module),
                        lastPlayed.formatted(.relative(presentation: .named))
                    ))
                    .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(String(
                    format: String(localized: "%lld%% watched", bundle: .module),
                    Int64(item.progress.fraction * 100)
                ))
                .foregroundStyle(Color.accentColor)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(
            isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrent && !isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .frame(width: 208)
        .contentShape(Rectangle())
        .modifier(VideoItemTapModifier(onOpen: onOpen, onSelect: onSelect))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cisum.video.rail.\(item.url.lastPathComponent)")
    }
}

/// 网格单元：封面 + 标题 + 评分 / 标签。macOS 单击选中、双击播放；触控平台轻点播放。
struct VideoGridCell: View {
    let item: VideoItem
    let isCurrent: Bool
    let isSelected: Bool
    let onOpen: () -> Void
    let onSelect: () -> Void

    #if os(macOS)
    @State private var isHovering = false
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            poster
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    if let rating = item.rating {
                        Text(String(repeating: "★", count: rating.value))
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    Text(item.tags.first ?? folderTitle)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
        }
        .padding(8)
        .background { background }
        .contentShape(Rectangle())
        .modifier(VideoItemTapModifier(onOpen: onOpen, onSelect: onSelect, onHover: hoverHandler))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cisum.video.item.\(item.url.lastPathComponent)")
    }

    private var hoverHandler: (Bool) -> Void {
        #if os(macOS)
        { isHovering = $0 }
        #else
        { _ in }
        #endif
    }

    private var folderTitle: String {
        item.folderPath.split(separator: "/").last.map(String.init) ?? ""
    }

    @ViewBuilder
    private var background: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(backgroundColor)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.12)
        }
        #if os(macOS)
        if isHovering {
            return Color.primary.opacity(0.05)
        }
        #endif
        return Color.clear
    }

    private var poster: some View {
        VideoThumbnailView(url: item.url)
            .overlay(alignment: .topTrailing) {
                VideoAvailabilityBadge(item: item)
                    .padding(6)
            }
            .overlay(alignment: .bottomTrailing) {
                Text(item.formattedDuration)
                    .font(.caption2.monospacedDigit())
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(.white)
                    .padding(5)
            }
            .overlay(alignment: .bottom) {
                if item.isInProgress {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(.white.opacity(0.25))
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: proxy.size.width * item.progress.fraction)
                        }
                    }
                    .frame(height: 3)
                }
            }
            .overlay {
                #if os(macOS)
                if isHovering {
                    Button(action: onOpen) {
                        Image(systemName: playSymbol)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(.black.opacity(0.55), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Play", bundle: .module))
                }
                #endif
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected || isCurrent ? Color.accentColor : Color.clear, lineWidth: isSelected ? 2 : 1.5)
            )
    }

    private var playSymbol: String {
        item.availability == .cloudNotDownloaded ? "icloud.and.arrow.down" : "play.fill"
    }
}

/// 列表行：缩略图、标题、次要信息、时长与下载状态。
struct VideoListRow: View {
    let item: VideoItem
    let isCurrent: Bool
    let isSelected: Bool
    let onOpen: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VideoThumbnailView(url: item.url, size: CGSize(width: 160, height: 90), cornerRadius: 6)
                .frame(width: 84)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isCurrent ? Color.accentColor : Color.clear, lineWidth: 1.5)
                )

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

            Text(item.tags.first ?? folderTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(item.formattedDuration)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            VideoAvailabilityBadge(item: item)
                .frame(width: 24, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .modifier(VideoItemTapModifier(onOpen: onOpen, onSelect: onSelect))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cisum.video.item.\(item.url.lastPathComponent)")
    }

    private var folderTitle: String {
        item.folderPath.split(separator: "/").last.map(String.init) ?? ""
    }

    private var secondaryTitle: String {
        if item.isInProgress {
            return String(
                format: String(localized: "%lld%% watched", bundle: .module),
                Int64(item.progress.fraction * 100)
            )
        }
        return item.formattedSize
    }
}

/// 条目的点击语义：macOS 单击选中（检查器）、双击播放；触控平台轻点播放。
private struct VideoItemTapModifier: ViewModifier {
    let onOpen: () -> Void
    let onSelect: () -> Void
    var onHover: (Bool) -> Void = { _ in }

    func body(content: Content) -> some View {
        content
            #if os(macOS)
            .onTapGesture(count: 2, perform: onOpen)
            .onTapGesture(perform: onSelect)
            .onHover(perform: onHover)
            #else
            .onTapGesture(perform: onOpen)
            #endif
    }
}

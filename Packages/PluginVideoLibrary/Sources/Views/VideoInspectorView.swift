import LumiUI
import ProviderVideo
import SwiftUI

/// 检查器：所选条目的封面播放、评分、收藏、标签、观看进度与文件信息。
struct VideoInspectorView: View {
    let item: VideoItem
    @ObservedObject var viewModel: VideoLibraryViewModel
    let presentation: VideoInspectorPresentation
    @Environment(\.videoPendingDeletion) private var pendingDeletion
    @State private var isRenaming = false
    @State private var name = ""
    @State private var renameError: String?
    @State private var newTag = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                thumbnail
                titleSection
                actionBar
                ratingRow
                primaryActions
                progressSection
                tagsSection
                infoSection
            }
            .padding(14)
        }
        .alert(
            String(localized: "Rename Failed", bundle: .module),
            isPresented: Binding(
                get: { renameError != nil },
                set: { if !$0 { renameError = nil } }
            )
        ) {
            Button(String(localized: "OK", bundle: .module)) {
                renameError = nil
            }
        } message: {
            Text(renameError ?? "")
        }
        .onChange(of: item.url) { _, _ in
            isRenaming = false
            newTag = ""
        }
    }

    // MARK: - Sections

    private var thumbnail: some View {
        ZStack(alignment: .topTrailing) {
            VideoThumbnailView(url: item.url, size: CGSize(width: 320, height: 180), cornerRadius: 10)
                .overlay {
                    Button {
                        viewModel.play(item)
                    } label: {
                        Image(systemName: item.availability == .cloudNotDownloaded
                            ? "icloud.and.arrow.down" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(18)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!item.availability.isPlayable)
                    .accessibilityLabel(String(localized: "Play", bundle: .module))
                    .accessibilityIdentifier("cisum.video.inspect.play")
                }

            if presentation == .sheet {
                Button {
                    viewModel.clearSelection()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(.black.opacity(0.55), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Close", bundle: .module))
                .accessibilityIdentifier("cisum.video.inspect.close")
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Button {
                    name = item.title
                    isRenaming = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "Rename", bundle: .module))
                .accessibilityIdentifier("cisum.video.inspect.rename")
                .disabled(isRenaming)
            }

            if isRenaming {
                TextField(String(localized: "Name", bundle: .module), text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(commitRename)
                    .accessibilityIdentifier("cisum.video.inspect.name")
                HStack {
                    Button(String(localized: "Save", bundle: .module), action: commitRename)
                        .buttonStyle(.borderedProminent)
                    Button(String(localized: "Cancel", bundle: .module)) {
                        isRenaming = false
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.small)
            }

            Text(metaLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var metaLine: String {
        [item.formattedSize, item.formattedDuration, folderTitle]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var folderTitle: String {
        let parts = item.folderPath.split(separator: "/")
        return parts.isEmpty ? String(localized: "Uncategorized", bundle: .module) : parts.joined(separator: " › ")
    }

    private func commitRename() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != item.title else {
            isRenaming = false
            return
        }
        do {
            try viewModel.rename(item, to: trimmed)
            isRenaming = false
        } catch {
            renameError = error.localizedDescription
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.toggleFavorite(item)
            } label: {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(item.isFavorite ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(item.isFavorite
                ? String(localized: "Remove from Favorites", bundle: .module)
                : String(localized: "Add to Favorites", bundle: .module))
            .accessibilityIdentifier("cisum.video.inspect.favorite")

            if item.availability == .cloudNotDownloaded {
                Button {
                    viewModel.requestDownload(item)
                } label: {
                    Image(systemName: "icloud.and.arrow.down")
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "Download", bundle: .module))
                .accessibilityIdentifier("cisum.video.inspect.download")
            }

            Spacer()

            #if os(macOS)
            if viewModel.repositoryURL != nil {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                } label: {
                    Image(systemName: "folder")
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "Show in Finder", bundle: .module))
                .accessibilityIdentifier("cisum.video.inspect.reveal")
            }
            #endif

            if let binding = pendingDeletion {
                Button {
                    binding.wrappedValue = item
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.red)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "Delete", bundle: .module))
                .accessibilityIdentifier("cisum.video.inspect.delete")
            }
        }
    }

    private var ratingRow: some View {
        HStack(spacing: 2) {
            Text(String(localized: "Rating", bundle: .module))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            ForEach(Array(VideoRating.allowedValues), id: \.self) { value in
                Button {
                    viewModel.setRating(item.rating?.value == value ? nil : value, for: item)
                } label: {
                    Image(systemName: (item.rating?.value ?? 0) >= value ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(value)")
                .accessibilityIdentifier("cisum.video.inspect.rating.\(value)")
            }
            Spacer()
        }
    }

    private var primaryActions: some View {
        VStack(spacing: 6) {
            Button {
                viewModel.play(item)
            } label: {
                Label(
                    item.isInProgress
                        ? String(
                            format: String(localized: "Resume from %@", bundle: .module),
                            VideoTimeFormatting.string(from: item.resumePosition ?? 0)
                        )
                        : String(localized: "Play", bundle: .module),
                    systemImage: "play.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!item.availability.isPlayable)
            .accessibilityIdentifier("cisum.video.resume")

            if item.isInProgress {
                Button {
                    viewModel.playFromBeginning(item)
                } label: {
                    Text(String(localized: "Play from Beginning", bundle: .module))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!item.availability.isPlayable)
                .accessibilityIdentifier("cisum.video.playFromStart")
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(String(localized: "Playback", bundle: .module))
                .font(.caption)
                .foregroundStyle(.secondary)
            if item.progress.lastPlayedAt != nil || item.progress.playCount > 0 {
                ProgressView(value: item.progress.fraction)
                    .accessibilityIdentifier("cisum.video.inspect.progress")
                Text(progressLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(String(localized: "Not played yet", bundle: .module))
                    .font(.caption)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    private var progressLine: String {
        var parts = [String(
            format: String(localized: "%lld%% watched", bundle: .module),
            Int64(item.progress.fraction * 100)
        )]
        if let lastPlayed = item.progress.lastPlayedAt {
            parts.append(String(
                format: String(localized: "Last played %@", bundle: .module),
                lastPlayed.formatted(date: .abbreviated, time: .shortened)
            ))
        }
        if item.progress.playCount > 0 {
            parts.append(String(
                format: String(localized: "Played %lld times", bundle: .module),
                Int64(item.progress.playCount)
            ))
        }
        return parts.joined(separator: " · ")
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(String(localized: "Tags", bundle: .module))
                .font(.caption)
                .foregroundStyle(.secondary)
            VideoWrapLayout(spacing: 6) {
                ForEach(item.tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text("#\(tag)")
                        Button {
                            viewModel.removeTag(tag, to: item)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 7, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(
                            format: String(localized: "Remove Tag %@", bundle: .module),
                            tag
                        ))
                    }
                    .font(.caption)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                }
            }
            .padding(.horizontal, 2)
            HStack {
                TextField(String(localized: "Add Tag", bundle: .module), text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTag)
                    .accessibilityIdentifier("cisum.video.inspect.tagInput")
                Button(String(localized: "Add", bundle: .module), action: addTag)
                    .buttonStyle(.bordered)
            }
            .controlSize(.small)
        }
    }

    private func addTag() {
        viewModel.addTag(newTag, to: item)
        newTag = ""
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            infoRow("Size", value: item.formattedSize)
            infoRow("Duration", value: item.formattedDuration)
            if let modifiedAt = item.modifiedAt {
                infoRow("Added", value: modifiedAt.formatted(date: .abbreviated, time: .omitted))
            }
            infoRow("Status", value: String(localized: String.LocalizationValue(item.availability.title), bundle: .module))
            if !viewModel.storageLocationTitle.isEmpty {
                infoRow("Location", value: String(
                    localized: String.LocalizationValue(viewModel.storageLocationTitle),
                    bundle: .module
                ))
            }
            infoRow("File", value: item.relativePath, lineLimit: 2)
        }
    }

    private func infoRow(_ key: LocalizedStringKey, value: String, lineLimit: Int = 1) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .font(.caption)
                .lineLimit(lineLimit)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

enum VideoInspectorPresentation {
    case column
    case sheet
}

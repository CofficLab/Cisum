import ProviderVideo
import SwiftUI

/// 条目详情面板：重命名、标签、评分、文件信息与文件操作。
struct VideoItemDetailSheet: View {
    let item: VideoItem
    @ObservedObject var viewModel: VideoLibraryViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var tagsText: String
    @State private var rating: Int?
    @State private var errorMessage: String?

    init(item: VideoItem, viewModel: VideoLibraryViewModel) {
        self.item = item
        self.viewModel = viewModel
        _name = State(initialValue: item.title)
        _tagsText = State(initialValue: VideoTagSupport.editableText(from: item.tags))
        _rating = State(initialValue: item.rating?.value)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    nameField
                    tagsField
                    ratingField
                    fileInfo
                    progressInfo
                }
                .padding(16)
            }
            Divider()
            footer
        }
        .frame(minWidth: 420, minHeight: 380)
    }

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 96, height: 54)
                .overlay {
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(item.relativePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(16)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Name", bundle: .module))
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(String(localized: "Name", bundle: .module), text: $name)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("cisum.video.editor.name")
        }
    }

    private var tagsField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Tags", bundle: .module))
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(String(localized: "Tags", bundle: .module), text: $tagsText, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
            Text(String(localized: "Separate tags with commas.", bundle: .module))
                .font(.caption2)
                .foregroundStyle(Color.secondary.opacity(0.7))
        }
    }

    private var ratingField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Rating", bundle: .module))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        rating = rating == value ? nil : value
                        viewModel.setRating(rating, for: item)
                    } label: {
                        Image(systemName: (rating ?? 0) >= value ? "star.fill" : "star")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.yellow)
                }
                Spacer()
                if rating != nil {
                    Button(String(localized: "Clear", bundle: .module)) {
                        rating = nil
                        viewModel.setRating(nil, for: item)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private var fileInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "File Info", bundle: .module))
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                infoRow(String(localized: "Size", bundle: .module), item.formattedSize)
                infoRow(String(localized: "Duration", bundle: .module), item.formattedDuration)
                infoRow(
                    String(localized: "Modified", bundle: .module),
                    item.modifiedAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "—"
                )
                infoRow(String(localized: "Location", bundle: .module), item.relativePath)
                infoRow(String(localized: "Status", bundle: .module), item.availability.title)
            }
        }
    }

    private var progressInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Playback", bundle: .module))
                .font(.caption)
                .foregroundStyle(.secondary)
            if item.progress.lastPlayedAt != nil || item.progress.playCount > 0 {
                Text(String(
                    format: String(localized: "Played %lld times · last played %@", bundle: .module),
                    Int64(item.progress.playCount),
                    item.progress.lastPlayedAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "—"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text(String(localized: "Not played yet", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button(role: .destructive) {
                delete()
            } label: {
                Label(String(localized: "Delete", bundle: .module), systemImage: "trash")
            }
            .buttonStyle(.borderless)

            #if os(macOS)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Label(String(localized: "Show in Finder", bundle: .module), systemImage: "folder")
            }
            .buttonStyle(.borderless)
            #endif

            Spacer()

            Button(String(localized: "Cancel", bundle: .module)) {
                dismiss()
            }

            Button(String(localized: "Save", bundle: .module)) {
                commit()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private func commit() {
        do {
            try viewModel.rename(item, to: name)
            viewModel.setTags(VideoTagSupport.normalizedTags(from: tagsText), for: item)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() {
        do {
            try viewModel.delete(item)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

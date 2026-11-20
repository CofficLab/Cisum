import ProviderVideo
import SwiftUI

/// 条目编辑面板：重命名、标签、评分。
struct VideoItemEditorSheet: View {
    let item: VideoItem
    let onRename: (String) throws -> Void
    let onTags: ([String]) -> Void
    let onRating: (Int?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var tagsText: String
    @State private var rating: Int?
    @State private var errorMessage: String?

    init(
        item: VideoItem,
        onRename: @escaping (String) throws -> Void,
        onTags: @escaping ([String]) -> Void,
        onRating: @escaping (Int?) -> Void
    ) {
        self.item = item
        self.onRename = onRename
        self.onTags = onTags
        self.onRating = onRating
        _name = State(initialValue: item.title)
        _tagsText = State(initialValue: VideoTagSupport.editableText(from: item.tags))
        _rating = State(initialValue: item.rating?.value)
    }

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "Name", bundle: .module), text: $name)
                    .accessibilityIdentifier("cisum.video.editor.name")
            }

            Section {
                TextField(String(localized: "Tags", bundle: .module), text: $tagsText, axis: .vertical)
                    .lineLimit(2...4)
                Text(String(localized: "Separate tags with commas.", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(String(localized: "Tags", bundle: .module))
            }

            Section {
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            rating = rating == value ? nil : value
                            onRating(rating)
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
                            onRating(nil)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            } header: {
                Text(String(localized: "Rating", bundle: .module))
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .onSubmit(commit)
    }

    private func commit() {
        do {
            try onRename(name)
            onTags(VideoTagSupport.normalizedTags(from: tagsText))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

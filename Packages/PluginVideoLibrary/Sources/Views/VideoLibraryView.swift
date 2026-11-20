import LumiUI
import ProviderVideo
import SwiftUI

/// 视频库列表：仓库状态栏 + 标签筛选 + 视频网格。
struct VideoLibraryView: View {
    @ObservedObject private var viewModel: VideoLibraryViewModel

    init(viewModel: VideoLibraryViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            repositoryHeader
            Divider()
            content
        }
        .accessibilityIdentifier("cisum.video.library")
        .sheet(item: Binding(
            get: { viewModel.editingItem },
            set: { viewModel.editingItem = $0 }
        )) { item in
            VideoItemEditorSheet(
                item: item,
                onRename: { try viewModel.rename(item, to: $0) },
                onTags: { viewModel.setTags($0, for: item) },
                onRating: { viewModel.setRating($0, for: item) }
            )
        }
    }

    // MARK: - Header

    private var repositoryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "externaldrive.badge.timachine")
                    .foregroundStyle(.secondary)
                Text(String(localized: "Video Library", bundle: .module))
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if viewModel.repositoryState.isWorking {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text(viewModel.repositoryState.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                if !viewModel.storageLocationTitle.isEmpty {
                    Label {
                        Text(viewModel.storageLocationTitle)
                    } icon: {
                        Image(systemName: viewModel.storageLocationTitle == "iCloud" ? "icloud" : "internaldrive")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    viewModel.refresh()
                } label: {
                    Label(String(localized: "Refresh", bundle: .module), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.repositoryURL == nil)
            }
            .controlSize(.small)

            TextField(String(localized: "Search", bundle: .module), text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("cisum.video.search")

            if !viewModel.allTags.isEmpty {
                tagFilters
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var tagFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip(
                    title: String(localized: "All", bundle: .module),
                    isSelected: viewModel.selectedTag == nil && !viewModel.favoritesOnly,
                    action: {
                        viewModel.selectedTag = nil
                        viewModel.favoritesOnly = false
                    }
                )
                filterChip(
                    title: String(localized: "Favorites", bundle: .module),
                    isSelected: viewModel.favoritesOnly,
                    action: {
                        viewModel.favoritesOnly.toggle()
                    }
                )
                ForEach(viewModel.allTags, id: \.self) { tag in
                    filterChip(
                        title: tag,
                        isSelected: viewModel.selectedTag == tag,
                        action: {
                            viewModel.selectedTag = viewModel.selectedTag == tag ? nil : tag
                        }
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.repositoryURL == nil {
            emptyState(
                icon: "internaldrive",
                title: String(localized: "No Repository", bundle: .module),
                message: String(localized: "Choose the storage location in Settings. Cisum creates the video repository inside it.", bundle: .module)
            )
        } else if viewModel.items.isEmpty {
            emptyState(
                icon: "film",
                title: String(localized: "No videos found", bundle: .module),
                message: String(localized: "This folder has no supported video files yet.", bundle: .module)
            )
        } else if viewModel.filteredItems.isEmpty {
            emptyState(
                icon: "line.3.horizontal.decrease.circle",
                title: String(localized: "No matching videos", bundle: .module),
                message: String(localized: "Try another search or clear the filters.", bundle: .module)
            )
        } else {
            grid
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 12)],
                spacing: 12
            ) {
                ForEach(viewModel.filteredItems) { item in
                    VideoGridCell(item: item, isCurrent: viewModel.currentItem?.url == item.url) {
                        viewModel.play(item)
                    }
                    .contextMenu {
                        Button {
                            viewModel.play(item)
                        } label: {
                            Label(String(localized: "Play", bundle: .module), systemImage: "play.fill")
                        }

                        Button {
                            viewModel.toggleFavorite(item)
                        } label: {
                            Label(
                                item.isFavorite
                                    ? String(localized: "Remove from Favorites", bundle: .module)
                                    : String(localized: "Add to Favorites", bundle: .module),
                                systemImage: item.isFavorite ? "star.slash" : "star"
                            )
                        }

                        Menu {
                            ForEach(1...5, id: \.self) { value in
                                Button {
                                    viewModel.setRating(value, for: item)
                                } label: {
                                    Label("\(value)", systemImage: item.rating?.value == value ? "star.fill" : "star")
                                }
                            }
                            Button {
                                viewModel.setRating(nil, for: item)
                            } label: {
                                Label(String(localized: "Clear Rating", bundle: .module), systemImage: "xmark.circle")
                            }
                        } label: {
                            Label(String(localized: "Rating", bundle: .module), systemImage: "star")
                        }

                        Button {
                            viewModel.editingItem = item
                        } label: {
                            Label(String(localized: "Edit Tags and Name", bundle: .module), systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            try? viewModel.delete(item)
                        } label: {
                            Label(String(localized: "Delete", bundle: .module), systemImage: "trash")
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

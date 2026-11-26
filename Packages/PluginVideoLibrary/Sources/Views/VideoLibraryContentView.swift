import ProviderVideo
import SwiftUI

/// 内容区：「继续观看」横栏 + 网格 / 列表。
struct VideoLibraryContentView: View {
    @ObservedObject var viewModel: VideoLibraryViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.showsContinueWatchingRail, !viewModel.continueWatchingItems.isEmpty {
                    continueRail
                }
                if viewModel.displayMode == .grid {
                    grid
                } else {
                    list
                }
            }
            .padding(12)
        }
        #if os(iOS) || os(visionOS)
        .refreshable {
            viewModel.refresh()
        }
        #endif
    }

    // MARK: - Continue watching

    private var continueRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Label(String(localized: "Continue Watching", bundle: .module), systemImage: "play.circle")
                    .font(.callout.weight(.semibold))
                Text(String(localized: "Pick up where you left off", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.continueWatchingItems.prefix(12)) { item in
                        VideoContinueRailCard(
                            item: item,
                            isCurrent: viewModel.currentItem?.url == item.url,
                            isSelected: viewModel.selectedItem?.url == item.url,
                            onOpen: { viewModel.play(item) },
                            onSelect: { viewModel.select(item) }
                        )
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 2)
            }
        }
        .accessibilityIdentifier("cisum.video.continue")
    }

    // MARK: - Grid / list

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(
                .adaptive(minimum: VideoLibraryLayoutPolicy.gridCellWidth.lowerBound,
                          maximum: VideoLibraryLayoutPolicy.gridCellWidth.upperBound),
                spacing: 12
            )],
            spacing: 14
        ) {
            ForEach(viewModel.filteredItems) { item in
                VideoGridCell(
                    item: item,
                    isCurrent: viewModel.currentItem?.url == item.url,
                    isSelected: viewModel.selectedItem?.url == item.url,
                    onOpen: { viewModel.play(item) },
                    onSelect: { viewModel.select(item) }
                )
                .contextMenu { itemMenu(for: item) }
            }
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.filteredItems) { item in
                VideoListRow(
                    item: item,
                    isCurrent: viewModel.currentItem?.url == item.url,
                    isSelected: viewModel.selectedItem?.url == item.url,
                    onOpen: { viewModel.play(item) },
                    onSelect: { viewModel.select(item) }
                )
                .contextMenu { itemMenu(for: item) }
                if item.id != viewModel.filteredItems.last?.id {
                    Divider()
                }
            }
        }
    }

    /// 条目的右键 / 长按菜单。
    @ViewBuilder
    private func itemMenu(for item: VideoItem) -> some View {
        Button {
            viewModel.play(item)
        } label: {
            Label(String(localized: "Play", bundle: .module), systemImage: "play.fill")
        }
        .disabled(item.availability != .available)

        if item.isInProgress {
            Button {
                viewModel.playFromBeginning(item)
            } label: {
                Label(String(localized: "Play from Beginning", bundle: .module), systemImage: "arrow.counterclockwise")
            }
            .disabled(item.availability != .available)
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

        if item.availability == .cloudNotDownloaded {
            Button {
                viewModel.requestDownload(item)
            } label: {
                Label(String(localized: "Download", bundle: .module), systemImage: "icloud.and.arrow.down")
            }
        }

        Button(role: .destructive) {
            try? viewModel.delete(item)
        } label: {
            Label(String(localized: "Delete", bundle: .module), systemImage: "trash")
        }
    }
}

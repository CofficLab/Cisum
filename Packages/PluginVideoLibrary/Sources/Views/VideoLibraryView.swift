import LumiUI
import ProviderVideo
import SwiftUI
import UniformTypeIdentifiers

/// 视频库：摘要与仓库操作、单行搜索筛选、单一网格或列表内容区。
struct VideoLibraryView: View {
    @ObservedObject private var viewModel: VideoLibraryViewModel
    @State private var isImporterPresented = false

    init(viewModel: VideoLibraryViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            filterBar
            Divider()
            content
        }
        .accessibilityIdentifier("cisum.video.library")
        #if os(iOS)
        .navigationTitle(String(localized: "Video Library", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $viewModel.searchText,
            prompt: String(localized: "Search", bundle: .module)
        )
        #endif
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: VideoFileSupport.importContentTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                viewModel.importVideos(from: urls)
            }
        }
        .sheet(item: Binding(
            get: { viewModel.editingItem },
            set: { viewModel.editingItem = $0 }
        )) { item in
            VideoItemDetailSheet(item: item, viewModel: viewModel)
        }
        .alert(
            String(localized: "Import Failed", bundle: .module),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(String(localized: "OK", bundle: .module)) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .modifier(VideoPlayerPresentation(viewModel: viewModel))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Label {
                Text(summaryTitle)
            } icon: {
                Image(systemName: viewModel.storageLocationTitle == "iCloud" ? "icloud" : "internaldrive")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            if viewModel.repositoryState.isWorking {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer(minLength: 8)

            Button {
                isImporterPresented = true
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(localized: "Import Videos", bundle: .module))
            .help(String(localized: "Import Videos", bundle: .module))
            .disabled(viewModel.repositoryURL == nil)

            Menu {
                Button {
                    viewModel.refresh()
                } label: {
                    Label(String(localized: "Refresh", bundle: .module), systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.repositoryURL == nil)

                #if os(macOS)
                if let url = viewModel.repositoryURL {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: {
                        Label(String(localized: "Show in Finder", bundle: .module), systemImage: "folder")
                    }
                }
                #endif
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel(String(localized: "More", bundle: .module))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var summaryTitle: String {
        String(
            format: String(localized: "%lld videos · %@", bundle: .module),
            Int64(viewModel.filteredItems.count),
            viewModel.totalSizeTitle
        )
    }

    // MARK: - Filters

    private var filterBar: some View {
        HStack(spacing: 8) {
            #if !os(iOS)
            AppSearchBar(text: $viewModel.searchText, placeholder: "Search")
                .accessibilityIdentifier("cisum.video.search")
            #endif

            Menu {
                ForEach(VideoLibraryScope.allCases, id: \.self) { scope in
                    Button {
                        viewModel.scope = scope
                    } label: {
                        Label {
                            Text("\(String(localized: String.LocalizationValue(scope.title), bundle: .module)) \(viewModel.count(for: scope))")
                        } icon: {
                            Image(systemName: viewModel.scope == scope ? "checkmark" : scope.systemImage)
                        }
                    }
                }

                if !viewModel.allTags.isEmpty {
                    Divider()
                    ForEach(viewModel.allTags, id: \.self) { tag in
                        Button {
                            viewModel.selectedTag = viewModel.selectedTag == tag ? nil : tag
                        } label: {
                            Label(tag, systemImage: viewModel.selectedTag == tag ? "checkmark" : "tag")
                        }
                    }
                }

                if viewModel.hasActiveFilters {
                    Divider()
                    Button(String(localized: "Clear Filters", bundle: .module)) {
                        viewModel.clearFilters()
                    }
                }
            } label: {
                Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
            .accessibilityLabel(String(localized: String.LocalizationValue(viewModel.scope.title), bundle: .module))
            .accessibilityIdentifier("cisum.video.filters")

            Menu {
                Picker("", selection: $viewModel.sortOrder) {
                    ForEach(VideoSortOrder.allCases, id: \.self) { order in
                        Label(String(localized: String.LocalizationValue(order.title), bundle: .module), systemImage: order.systemImage)
                            .tag(order)
                    }
                }
                .labelsHidden()
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle")
            }
            .accessibilityLabel(String(localized: String.LocalizationValue(viewModel.sortOrder.title), bundle: .module))

            #if os(iOS)
            Spacer(minLength: 8)
            #endif

            Picker("", selection: $viewModel.displayMode) {
                ForEach(VideoLibraryDisplayMode.allCases, id: \.self) { mode in
                    Image(systemName: mode.systemImage).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()
            .accessibilityIdentifier("cisum.video.displaymode")
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if case .unavailable(let reason) = viewModel.repositoryState {
            VideoLibraryEmptyState(
                icon: "externaldrive.badge.exclamationmark",
                title: String(localized: "Repository Unavailable", bundle: .module),
                message: reason,
                actionTitle: String(localized: "Refresh", bundle: .module),
                action: { viewModel.refresh() }
            )
        } else if viewModel.repositoryState.isWorking && viewModel.items.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text(String(localized: String.LocalizationValue(viewModel.repositoryState.title), bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("cisum.video.loading")
        } else if viewModel.repositoryURL == nil {
            VideoLibraryEmptyState(
                icon: "internaldrive",
                title: String(localized: "No Repository", bundle: .module),
                message: String(localized: "Choose the storage location in Settings. Cisum creates the video repository inside it.", bundle: .module)
            )
        } else if viewModel.items.isEmpty {
            VideoLibraryEmptyState(
                icon: "film",
                title: String(localized: "No videos found", bundle: .module),
                message: String(localized: "This folder has no supported video files yet.", bundle: .module),
                actionTitle: String(localized: "Import Videos", bundle: .module),
                action: { isImporterPresented = true }
            )
        } else if viewModel.filteredItems.isEmpty {
            VideoLibraryEmptyState(
                icon: "line.3.horizontal.decrease.circle",
                title: String(localized: "No matching videos", bundle: .module),
                message: String(localized: "Try another search or clear the filters.", bundle: .module),
                actionTitle: String(localized: "Clear Filters", bundle: .module),
                action: { viewModel.clearFilters() }
            )
        } else {
            libraryContent
        }
    }

    private var libraryContent: some View {
        ScrollView {
            Group {
                if viewModel.displayMode == .grid {
                    grid
                } else {
                    list
                }
            }
            .padding(12)
        }
        #if os(iOS)
        .refreshable {
            viewModel.refresh()
        }
        #endif
    }

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 12)],
            spacing: 12
        ) {
            ForEach(viewModel.filteredItems) { item in
                VideoGridCell(
                    item: item,
                    isCurrent: viewModel.currentItem?.url == item.url,
                    onPlay: { viewModel.play(item) },
                    onFavorite: { viewModel.toggleFavorite(item) },
                    onOpen: { viewModel.editingItem = item }
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
                    onPlay: { viewModel.play(item) },
                    onOpen: { viewModel.editingItem = item }
                )
                .contextMenu { itemMenu(for: item) }
                Divider()
            }
        }
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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

/// iOS 使用系统全屏呈现；macOS 由插件在根布局登记 Overlay。
private struct VideoPlayerPresentation: ViewModifier {
    @ObservedObject var viewModel: VideoLibraryViewModel

    func body(content: Content) -> some View {
        #if os(iOS)
        content.fullScreenCover(isPresented: $viewModel.isPlayerPresented) {
            VideoPlayerOverlay(viewModel: viewModel) {
                viewModel.dismissPlayer()
            }
        }
        #else
        content
        #endif
    }
}

import LumiUI
import ProviderVideo
import SwiftUI
import UniformTypeIdentifiers

/// 视频库列表：仓库信息栏 + 筛选栏 + 内容区（网格 / 列表）。
///
/// 平台差异：
/// - macOS：顶部信息栏常驻，悬停海报浮出操作条，右键菜单保留全部操作。
/// - iOS：走导航栏标题 + 下拉刷新，导入使用系统文件选择器，操作走长按菜单。
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
        .navigationBarTitleDisplayMode(.large)
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

            locationRow

            HStack(spacing: 8) {
                Button {
                    isImporterPresented = true
                } label: {
                    Label(String(localized: "Import Videos", bundle: .module), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.repositoryURL == nil)

                Button {
                    viewModel.refresh()
                } label: {
                    Label(String(localized: "Refresh", bundle: .module), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.repositoryURL == nil)

                #if os(macOS)
                if let url = viewModel.repositoryURL {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: {
                        Label(String(localized: "Show in Finder", bundle: .module), systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                #endif

                Spacer()

                Text(summaryTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var locationRow: some View {
        HStack(spacing: 6) {
            if !viewModel.storageLocationTitle.isEmpty {
                Label {
                    Text(viewModel.storageLocationTitle)
                } icon: {
                    Image(systemName: viewModel.storageLocationTitle == "iCloud" ? "icloud" : "internaldrive")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if let url = viewModel.repositoryURL {
                Text(url.path)
                    .font(.caption2)
                    .foregroundStyle(Color.secondary.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
    }

    private var summaryTitle: String {
        let count = viewModel.filteredItems.count
        let size = viewModel.totalSizeTitle
        return String(
            format: String(localized: "%lld videos · %@", bundle: .module),
            Int64(count),
            size
        )
    }

    // MARK: - Filters

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField(String(localized: "Search", bundle: .module), text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("cisum.video.search")

                Picker("", selection: $viewModel.sortOrder) {
                    ForEach(VideoSortOrder.allCases, id: \.self) { order in
                        Text(String(localized: String.LocalizationValue(order.title), bundle: .module))
                            .tag(order)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()

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

            scopeChips

            if !viewModel.allTags.isEmpty {
                tagChips
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var scopeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(VideoLibraryScope.allCases, id: \.self) { scope in
                    filterChip(
                        title: "\(String(localized: String.LocalizationValue(scope.title), bundle: .module)) \(viewModel.count(for: scope))",
                        isSelected: viewModel.scope == scope,
                        action: { viewModel.scope = scope }
                    )
                }
                if viewModel.hasActiveFilters {
                    filterChip(
                        title: String(localized: "Clear Filters", bundle: .module),
                        isSelected: false,
                        action: { viewModel.clearFilters() }
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var tagChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
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
            VideoLibraryEmptyState(
                icon: "internaldrive",
                title: String(localized: "No Repository", bundle: .module),
                message: String(localized: "Choose the storage location in Settings. Cisum creates the video repository inside it.", bundle: .module),
                primaryTitle: nil,
                primaryAction: nil,
                secondaryTitle: nil,
                secondaryAction: nil
            )
        } else if viewModel.items.isEmpty {
            VideoLibraryEmptyState(
                icon: "film",
                title: String(localized: "No videos found", bundle: .module),
                message: String(localized: "This folder has no supported video files yet.", bundle: .module),
                primaryTitle: String(localized: "Import Videos", bundle: .module),
                primaryAction: { isImporterPresented = true },
                secondaryTitle: String(localized: "Refresh", bundle: .module),
                secondaryAction: { viewModel.refresh() }
            )
        } else if viewModel.filteredItems.isEmpty {
            VideoLibraryEmptyState(
                icon: "line.3.horizontal.decrease.circle",
                title: String(localized: "No matching videos", bundle: .module),
                message: String(localized: "Try another search or clear the filters.", bundle: .module),
                primaryTitle: String(localized: "Clear Filters", bundle: .module),
                primaryAction: { viewModel.clearFilters() },
                secondaryTitle: nil,
                secondaryAction: nil
            )
        } else {
            libraryContent
        }
    }

    private var libraryContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if viewModel.scope == .all, !viewModel.continueWatchingItems.isEmpty {
                    continueWatchingSection
                }

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

    private var continueWatchingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "Continue Watching", bundle: .module))
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.continueWatchingItems) { item in
                        VideoGridCell(
                            item: item,
                            isCurrent: viewModel.currentItem?.url == item.url,
                            onPlay: { viewModel.play(item) },
                            onFavorite: { viewModel.toggleFavorite(item) },
                            onOpen: { viewModel.editingItem = item }
                        )
                        .frame(width: 220)
                        .contextMenu { itemMenu(for: item) }
                    }
                }
                .padding(.vertical, 2)
            }
        }
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

/// 播放器的呈现方式：macOS 用层叠覆盖，iOS 用全屏 sheet。
private struct VideoPlayerPresentation: ViewModifier {
    @ObservedObject var viewModel: VideoLibraryViewModel

    func body(content: Content) -> some View {
        #if os(iOS)
        content.fullScreenCover(isPresented: $viewModel.isPlayerPresented) {
            VideoPlayerOverlay(viewModel: viewModel) {
                viewModel.isPlayerPresented = false
            }
        }
        #else
        content.overlay {
            if viewModel.isPlayerPresented {
                VideoPlayerOverlay(viewModel: viewModel) {
                    viewModel.isPlayerPresented = false
                }
                .transition(.opacity)
            }
        }
        #endif
    }
}

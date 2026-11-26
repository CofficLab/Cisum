import LumiUI
import ProviderVideo
import SwiftUI
import UniformTypeIdentifiers

enum VideoLibraryContentState: Equatable {
    case unavailable(String)
    case loading
    case noRepository
    case emptyRepository
    case noMatches
    case library

    static func resolve(
        repositoryState: VideoRepositoryState,
        repositoryURL: URL?,
        itemCount: Int,
        filteredItemCount: Int
    ) -> Self {
        if case .unavailable(let reason) = repositoryState {
            return .unavailable(reason)
        }
        if repositoryState.isWorking && itemCount == 0 {
            return .loading
        }
        if repositoryURL == nil {
            return .noRepository
        }
        if itemCount == 0 {
            return .emptyRepository
        }
        if filteredItemCount == 0 {
            return .noMatches
        }
        return .library
    }
}

/// 检查器发起「删除」确认的通道：确认框挂在库根视图上，列与面板两种形态共用。
struct VideoPendingDeletionKey: EnvironmentKey {
    static let defaultValue: Binding<VideoItem?>? = nil
}

extension EnvironmentValues {
    var videoPendingDeletion: Binding<VideoItem?>? {
        get { self[VideoPendingDeletionKey.self] }
        set { self[VideoPendingDeletionKey.self] = newValue }
    }
}

/// 视频库：资料库优先的布局。宽窗口为「侧栏 / 内容 / 检查器」三栏，
/// 变窄时检查器与侧栏依次收成面板，iOS 始终单栏。
struct VideoLibraryView: View {
    @ObservedObject private var viewModel: VideoLibraryViewModel
    /// 视图出现后的回调（macOS 用于在窗口就绪后应用场景窗口尺寸）。
    private let onAppear: @MainActor () -> Void
    @State private var isImporterPresented = false
    @State private var isSidebarPresented = false
    @State private var pendingDeletion: VideoItem?

    init(viewModel: VideoLibraryViewModel, onAppear: @escaping @MainActor () -> Void = {}) {
        self.viewModel = viewModel
        self.onAppear = onAppear
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = VideoLibraryLayoutPolicy.layout(forWidth: proxy.size.width)
            ZStack(alignment: .leading) {
                rootLayout(for: layout)
                if !VideoLibraryLayoutPolicy.showsSidebar(layout), isSidebarPresented {
                    compactSidebar
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .sheet(isPresented: inspectorPresented(for: layout)) {
                if let item = viewModel.selectedItem {
                    VideoInspectorView(item: item, viewModel: viewModel, presentation: .sheet)
                        .frame(width: 340, height: 560)
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isSidebarPresented)
        .onAppear(perform: onAppear)
        .modifier(VideoPlayerPresentation(viewModel: viewModel))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cisum.video.library")
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: VideoFileSupport.importContentTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                viewModel.importVideos(from: urls)
            }
        }
        .sheet(item: $viewModel.editingItem) { item in
            VideoItemDetailSheet(item: item, viewModel: viewModel)
        }
        .confirmationDialog(
            String(
                format: String(localized: "Delete “%@”?", bundle: .module),
                pendingDeletion?.title ?? ""
            ),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete", bundle: .module), role: .destructive) {
                if let item = pendingDeletion {
                    try? viewModel.delete(item)
                }
                pendingDeletion = nil
            }
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text(String(localized: "The file is moved to the Trash.", bundle: .module))
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
        .environment(\.videoPendingDeletion, $pendingDeletion)
    }

    // MARK: - Layout

    /// 检查器以面板呈现：无检查器列的布局（侧栏也收成面板）时选中即弹出。
    private func inspectorPresented(for layout: VideoLibraryLayout) -> Binding<Bool> {
        Binding(
            get: {
                !VideoLibraryLayoutPolicy.showsInspectorColumn(layout) && viewModel.selectedItem != nil
            },
            set: { if !$0 { viewModel.clearSelection() } }
        )
    }

    @ViewBuilder
    private func rootLayout(for layout: VideoLibraryLayout) -> some View {
        switch layout {
        case .wide:
            HStack(spacing: 0) {
                VideoSidebarView(viewModel: viewModel)
                    .frame(width: VideoLibraryLayoutPolicy.sidebarWidth)
                Divider()
                mainColumn(layout: layout)
                if let item = viewModel.selectedItem {
                    Divider()
                    VideoInspectorView(item: item, viewModel: viewModel, presentation: .column)
                        .frame(width: VideoLibraryLayoutPolicy.inspectorWidth)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: viewModel.selectedItem?.url)
        case .medium, .compact:
            mainColumn(layout: layout)
        }
    }

    private func mainColumn(layout: VideoLibraryLayout) -> some View {
        VStack(spacing: 0) {
            VideoLibraryHeaderView(
                viewModel: viewModel,
                layout: layout,
                onToggleSidebar: { isSidebarPresented.toggle() },
                onImport: { isImporterPresented = true }
            )
            Divider()
            content
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel.playback.hasAsset, !viewModel.isPlayerPresented {
                VideoMiniPlayerView(viewModel: viewModel)
                    .padding(12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isPlayerPresented)
    }

    private var compactSidebar: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { isSidebarPresented = false }
            VideoSidebarView(viewModel: viewModel)
                .frame(width: 260)
                .background(.regularMaterial)
                .transition(.move(edge: .leading))
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let state = VideoLibraryContentState.resolve(
            repositoryState: viewModel.repositoryState,
            repositoryURL: viewModel.repositoryURL,
            itemCount: viewModel.items.count,
            filteredItemCount: viewModel.filteredItems.count
        )

        switch state {
        case .unavailable(let reason):
            VideoLibraryEmptyState(
                icon: "externaldrive.badge.exclamationmark",
                title: String(localized: "Repository Unavailable", bundle: .module),
                message: reason,
                actionTitle: String(localized: "Refresh", bundle: .module),
                action: { viewModel.refresh() }
            )
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text(String(localized: String.LocalizationValue(viewModel.repositoryState.title), bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("cisum.video.loading")
        case .noRepository:
            VideoLibraryEmptyState(
                icon: "internaldrive",
                title: String(localized: "No Repository", bundle: .module),
                message: String(localized: "Choose the storage location in Settings. Cisum creates the video repository inside it.", bundle: .module)
            )
        case .emptyRepository:
            VideoLibraryEmptyState(
                icon: "film",
                title: String(localized: "No videos found", bundle: .module),
                message: String(localized: "This folder has no supported video files yet.", bundle: .module),
                actionTitle: String(localized: "Import Videos", bundle: .module),
                action: { isImporterPresented = true }
            )
        case .noMatches:
            VideoLibraryEmptyState(
                icon: "line.3.horizontal.decrease.circle",
                title: String(localized: "No matching videos", bundle: .module),
                message: String(localized: "Try another search or clear the filters.", bundle: .module),
                actionTitle: String(localized: "Clear Filters", bundle: .module),
                action: { viewModel.clearFilters() }
            )
            .accessibilityIdentifier("cisum.video.no-matches")
        case .library:
            VideoLibraryContentView(viewModel: viewModel)
        }
    }
}

/// iOS / visionOS 用系统全屏呈现播放器；macOS 由插件在根布局登记覆盖层。
private struct VideoPlayerPresentation: ViewModifier {
    @ObservedObject var viewModel: VideoLibraryViewModel

    func body(content: Content) -> some View {
        #if os(iOS) || os(visionOS)
        content
            .navigationTitle(String(localized: "Video Library", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.searchText,
                prompt: String(localized: "Search", bundle: .module)
            )
            .fullScreenCover(isPresented: $viewModel.isPlayerPresented) {
                VideoPlayerOverlay(viewModel: viewModel) {
                    viewModel.dismissPlayer()
                }
            }
        #else
        content
        #endif
    }
}

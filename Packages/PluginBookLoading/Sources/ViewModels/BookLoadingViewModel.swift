import Foundation
import ProviderPlayback
import ProviderScene

/// 载入横幅的显示状态；外部变化只通过 Observer 写入。
///
/// 只有「有声书场景 + iCloud 载入中/失败」才产生非隐藏状态。音乐场景
/// 即使正在下载也保持 `.hidden`，音乐侧的显示由音乐自己的部件负责。
@MainActor
final class BookLoadingViewModel: ObservableObject {
    enum BannerMode: Equatable {
        /// 不呈现横幅。
        case hidden
        /// 正在从 iCloud 载入；`nil` 表示进度未知（渲染不确定态，而不是 0%）。
        case downloading(progress: Double?)
        /// 载入失败；detail 为引擎原始原因，仅用于 tooltip 与无障碍提示。
        case failed(detail: String)
    }

    @Published private(set) var mode: BannerMode = .hidden
    /// 章节名先按文件名立即呈现，书籍库返回后再补成「书名 + 章节位置」。
    @Published private(set) var subject: BookLoadingSubject = .empty

    private weak var playback: (any BookLoadingPlaybackCapability)?
    private let library: (any BookLoadingLibraryCapability)?
    private var currentScene: AppScene?
    private var subjectTask: Task<Void, Never>?
    private var subjectGeneration = 0

    init(
        playback: (any BookLoadingPlaybackCapability)?,
        scene: AppScene?,
        library: (any BookLoadingLibraryCapability)? = nil
    ) {
        self.playback = playback
        self.library = library
        self.currentScene = scene
        mode = Self.resolvedMode(state: playback?.state ?? .idle, scene: scene)
        updateSubject(for: playback?.currentURL)
    }

    func handleSceneChanged(_ scene: AppScene?) {
        currentScene = scene
        mode = Self.resolvedMode(state: playback?.state ?? .idle, scene: scene)
    }

    func handleStateChanged(_ state: PlaybackStatus) {
        mode = Self.resolvedMode(state: state, scene: currentScene)
    }

    func handleAssetChanged(_ url: URL?) {
        updateSubject(for: url)
    }

    func cancel() {
        playback?.cancelPendingLoad()
    }

    func retry() {
        Task { [weak self] in
            await self?.playback?.retryLastFailedLoad()
        }
    }

    func stop() {
        subjectTask?.cancel()
        subjectTask = nil
    }

    // MARK: - Subject

    private func updateSubject(for url: URL?) {
        subjectGeneration += 1
        let generation = subjectGeneration
        subjectTask?.cancel()

        guard let url else {
            subject = .empty
            return
        }

        // 立即给出章节名，避免横幅先空一拍。
        subject = BookLoadingSubject(chapterTitle: url.title)

        subjectTask = Task { [weak self] in
            guard let self else { return }
            let books = await self.library?.books() ?? []
            let libraryDisk = self.library?.libraryDisk
            let extensions = self.library?.playableExtensions ?? []

            let resolved = await Task.detached(priority: .utility) {
                BookLoadingSubjectResolver.resolve(
                    chapterURL: url,
                    books: books,
                    libraryDisk: libraryDisk,
                    playableExtensions: extensions
                )
            }.value

            guard !Task.isCancelled, generation == self.subjectGeneration else { return }
            self.subject = resolved
        }
    }

    // MARK: - Mode derivation

    /// 状态 + 场景 → 横幅模式。
    static func resolvedMode(state: PlaybackStatus, scene: AppScene?) -> BannerMode {
        guard scene == .audiobooks else { return .hidden }
        return mode(for: state)
    }

    /// 仅从播放状态推导横幅模式。
    static func mode(for state: PlaybackStatus) -> BannerMode {
        switch state {
        case .loading(.downloading(let progress)):
            let clamped = min(max(progress, 0), 1)
            return .downloading(progress: clamped > 0 ? clamped : nil)
        case .failed(.iCloudDownloadFailed(let detail)):
            return .failed(detail: detail)
        default:
            return .hidden
        }
    }
}
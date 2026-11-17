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
    @Published private(set) var subject: String = ""

    private weak var playback: (any BookLoadingPlaybackCapability)?
    private var currentScene: AppScene?

    init(
        playback: (any BookLoadingPlaybackCapability)?,
        scene: AppScene?
    ) {
        self.playback = playback
        self.currentScene = scene
        subject = Self.subject(for: playback?.currentURL)
        mode = Self.resolvedMode(state: playback?.state ?? .idle, scene: scene)
    }

    func handleSceneChanged(_ scene: AppScene?) {
        currentScene = scene
        mode = Self.resolvedMode(state: playback?.state ?? .idle, scene: scene)
    }

    func handleStateChanged(_ state: PlaybackStatus) {
        mode = Self.resolvedMode(state: state, scene: currentScene)
    }

    func handleAssetChanged(_ url: URL?) {
        subject = Self.subject(for: url)
    }

    func cancel() {
        playback?.cancelPendingLoad()
    }

    func retry() {
        Task { [weak self] in
            await self?.playback?.retryLastFailedLoad()
        }
    }

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

    /// 章节名取文件名的 stem；没有资源时为空串。
    static func subject(for url: URL?) -> String {
        url?.deletingPathExtension().lastPathComponent ?? ""
    }
}

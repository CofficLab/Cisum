import Combine
import Foundation
import OSLog
import ProviderScene
import MagicKit
import ProviderAudioLike

/// 喜欢列表加载闭包（由插件入口组装本地仓库）。
typealias AudioLikeLoadProvider = @MainActor () async -> [AudioLikeItem]

/// 喜欢状态保存闭包（由插件入口组装本地仓库）。
typealias AudioLikeSaveProvider = @MainActor (_ audioId: String, _ liked: Bool, _ url: URL?, _ title: String?) async throws -> Void

/// 音频喜欢的集中状态容器（迁移 Phase 2）。
///
/// 统一管理：
/// - 目标场景激活时的播放器「喜欢状态」订阅与保存（原 `AudioLikeRootView` 逻辑）；
/// - 喜欢列表的加载与刷新（原 `AudioLikeSettingsView` 逻辑）。
///
/// 由插件入口持有并注入 `AudioLikeObserver`；View 只展示与转发意图。
/// ViewModel 不直接持有 Kernel 或具体 Provider：播放服务可用性通过
/// `AudioLikePlaybackCapability` 表达，本地喜欢仓库由插件入口组装为闭包注入。
@MainActor
final class AudioLikeViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var likedAudios: [AudioLikeItem] = []
    @Published private(set) var isLoading = true

    private let playbackCapability: (any AudioLikePlaybackCapability)?
    private let loadLikedAudios: AudioLikeLoadProvider
    private let saveLikeStatus: AudioLikeSaveProvider
    private var loadGeneration = 0
    private var isActive = false

    init(
        playbackCapability: (any AudioLikePlaybackCapability)?,
        loadLikedAudios: @escaping AudioLikeLoadProvider,
        saveLikeStatus: @escaping AudioLikeSaveProvider
    ) {
        self.playbackCapability = playbackCapability
        self.loadLikedAudios = loadLikedAudios
        self.saveLikeStatus = saveLikeStatus
    }

    /// 场景变化：目标场景激活喜欢保存，离开目标场景停用。
    func handleSceneChange(_ sceneValue: AppScene?, targetScene: AppScene) {
        if sceneValue == targetScene {
            activateLike()
        } else {
            deactivateLike()
        }
    }

    /// 重新加载喜欢列表（首次加载与状态变化后刷新）。
    func reloadLikedAudios() {
        loadGeneration += 1
        let generation = loadGeneration

        Task { @MainActor in
            let audios = await loadLikedAudios()
            guard generation == self.loadGeneration else { return }
            self.likedAudios = audios
            self.isLoading = false
        }
    }

    // MARK: - Like activation

    private func activateLike() {
        guard !isActive else { return }
        guard playbackCapability?.isAvailable == true else { return }

        isActive = true
        // Playback events are adapted by AudioLikeObserver.
    }

    private func deactivateLike() {
        isActive = false
    }

    func handleLikeStatusChanged(asset url: URL, liked: Bool) {
        guard isActive else { return }

        Task { @MainActor in
            let audioId = url.absoluteString

            do {
                try await saveLikeStatus(
                    audioId,
                    liked,
                    url,
                    url.lastPathComponent
                )

                NotificationCenter.postAudioLikeStatusChanged(audioId: audioId, url: url, liked: liked)
            } catch {
                guard self.isActive else { return }
                os_log(.error, "保存喜欢状态失败: \(error.localizedDescription)")
                alert_error(String(localized: "Failed to save like status: \(error.localizedDescription)", bundle: .module))
            }
        }
    }
}

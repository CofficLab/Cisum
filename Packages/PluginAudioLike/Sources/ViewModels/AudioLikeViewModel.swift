import Combine
import Foundation
import OSLog
import ProviderScene
import MagicKit
import ProviderAudioLike

/// 音频喜欢的集中状态容器（迁移 Phase 2）。
///
/// 统一管理：
/// - 目标场景激活时的播放器「喜欢状态」订阅与保存（原 `AudioLikeRootView` 逻辑）；
/// - 喜欢列表的加载与刷新（原 `AudioLikeSettingsView` 逻辑）。
///
/// 由插件入口持有并注入 `AudioLikeObserver`；View 只展示与转发意图。
///
/// 喜欢仓库经 `AudioLikeRepositoryCapability` 读写（见 Capabilities 目录），
/// 不直接持有 `AudioLikeProviding`——虽然本插件自己注册该 Provider，
/// 消费侧同样需要收窄；播放服务可用性由插件入口按 Provider 是否存在注入。
@MainActor
final class AudioLikeViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var likedAudios: [AudioLikeItem] = []
    @Published private(set) var isLoading = true

    private let isPlaybackAvailable: Bool
    /// 喜欢仓库能力（Capabilities 目录收窄），`weak` 持有。
    private weak var repository: (any AudioLikeRepositoryCapability)?
    private weak var toast: (any AudioLikeToastCapability)?
    private var loadGeneration = 0
    private var isActive = false

    init(
        isPlaybackAvailable: Bool,
        repository: (any AudioLikeRepositoryCapability)?,
        toast: (any AudioLikeToastCapability)? = nil
    ) {
        self.isPlaybackAvailable = isPlaybackAvailable
        self.repository = repository
        self.toast = toast
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
            let audios = await self.repository?.allLiked() ?? []
            guard generation == self.loadGeneration else { return }
            self.likedAudios = audios
            self.isLoading = false
        }
    }

    // MARK: - Like activation

    private func activateLike() {
        guard !isActive else { return }
        guard isPlaybackAvailable else { return }

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
                try await self.repository?.updateLikeStatus(
                    audioId: audioId,
                    liked: liked,
                    url: url,
                    title: url.lastPathComponent
                )

                NotificationCenter.postAudioLikeStatusChanged(audioId: audioId, url: url, liked: liked)
            } catch {
                guard self.isActive else { return }
                os_log(.error, "保存喜欢状态失败: \(error.localizedDescription)")
                self.toast?.error(String(localized: "Failed to save like status: \(error.localizedDescription)", bundle: .module))
            }
        }
    }
}

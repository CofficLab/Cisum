import Combine
import Foundation
import OSLog
import ProviderScene
import SwiftUI
import ProviderPlayback
import MagicKit

/// 喜欢列表加载闭包（由插件入口组装本地仓库）。
typealias BookLikeLoadProvider = @MainActor () -> [BookLikeItem]

/// 喜欢状态保存闭包（由插件入口组装本地仓库）。
typealias BookLikeSaveProvider = @MainActor (_ liked: Bool, _ url: URL) -> Void

/// 书籍喜欢设置的集中状态容器（迁移 Phase 5）。
///
/// 统一管理：
/// - 目标场景激活时的播放器「喜欢状态」订阅与保存（原 `BookLikeRootView` 逻辑）；
/// - 喜欢列表的加载与刷新（原 `BookLikeSettingsView` 逻辑）。
///
/// 由插件入口持有并注入 `BookLikeObserver`；View 只展示与转发意图。
/// ViewModel 不直接持有 Kernel 或具体播放器：播放服务通过共享 Provider 契约注入，
/// 本地喜欢仓库由插件入口组装为闭包注入。
@MainActor
final class BookLikeViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var likedBooks: [BookLikeItem] = []
    @Published private(set) var isLoading = true

    private let playbackProvider: (any PlaybackProviding)?
    private let loadLikedBooks: BookLikeLoadProvider
    private let saveLikeStatus: BookLikeSaveProvider
    private let targetScene: AppScene
    private var isActive = false

    init(
        targetScene: AppScene = .audiobooks,
        playbackProvider: (any PlaybackProviding)?,
        loadLikedBooks: @escaping BookLikeLoadProvider,
        saveLikeStatus: @escaping BookLikeSaveProvider
    ) {
        self.targetScene = targetScene
        self.playbackProvider = playbackProvider
        self.loadLikedBooks = loadLikedBooks
        self.saveLikeStatus = saveLikeStatus
    }

    /// 场景变化：目标场景激活喜欢保存，离开目标场景停用。
    func handleSceneChange(_ sceneValue: AppScene?) {
        if sceneValue == targetScene {
            activateLike()
        } else {
            deactivateLike()
        }
    }

    func handleAppear() {
        reloadLikedBooks()
    }

    func handleLikeStatusChanged() {
        reloadLikedBooks()
    }

    func handleLikeStatusChanged(asset: URL, liked: Bool) {
        guard isActive else { return }
        if Self.verbose { os_log("\(Self.t)❤️/💔 喜欢状态变更: \(asset.lastPathComponent) -> \(liked)") }

        saveLikeStatus(liked, asset)
        handleLikeStatusChanged()
    }

    /// 重新加载喜欢列表（首次加载与状态变化后刷新）。
    func reloadLikedBooks() {
        likedBooks = loadLikedBooks()
        isLoading = false
        if Self.verbose { os_log("\(Self.t)📖 喜欢列表已加载: \(self.likedBooks.count) 本") }
    }

    // MARK: - Like activation

    private func activateLike() {
        guard !isActive else { return }
        guard playbackProvider != nil else { return }

        isActive = true
        if Self.verbose { os_log("\(Self.t)🟢 喜欢保存已激活") }
        // Playback events are adapted by BookLikeObserver.
    }

    private func deactivateLike() {
        if Self.verbose { os_log("\(Self.t)⏹️ 喜欢保存已停用") }
        isActive = false
    }
}

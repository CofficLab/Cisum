import ProviderPlayback
import SwiftUI
import MagicKit

/// 播放封面区域的状态；播放变化由 Observer 转发，媒体视图由 Provider 提供。
@MainActor
final class PlaybackHeroViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var currentURL: URL?
    @Published private(set) var state: PlaybackStatus
    @Published private(set) var isRepositoryEmpty = false
    @Published private(set) var isMusicSceneActive: Bool

    var isHeroVisible: Bool {
        currentURL != nil && !(isMusicSceneActive && isRepositoryEmpty)
    }

    private let mediaProvider: (any PlaybackMediaProviding)?

    init(
        playbackProvider: (any PlaybackProviding)?,
        mediaProvider: (any PlaybackMediaProviding)? = nil,
        isMusicSceneActive: Bool = true
    ) {
        self.mediaProvider = mediaProvider
        self.currentURL = playbackProvider?.currentURL
        self.state = playbackProvider?.state ?? .idle
        self.isMusicSceneActive = isMusicSceneActive
    }

    func applyAssetChanged(_ url: URL?) {
        currentURL = url
    }

    func applyStateChanged(_ state: PlaybackStatus) {
        self.state = state
    }

    func applyRepositoryEmpty(_ isEmpty: Bool) {
        isRepositoryEmpty = isEmpty
    }

    func applyMusicSceneActive(_ isActive: Bool) {
        isMusicSceneActive = isActive
    }

    func makeMediaView() -> AnyView {
        mediaProvider?.makeMediaView() ?? AnyView(EmptyView())
    }

    func localizedStateText() -> String {
        mediaProvider?.localizedStateText(for: state) ?? String(describing: state)
    }
}

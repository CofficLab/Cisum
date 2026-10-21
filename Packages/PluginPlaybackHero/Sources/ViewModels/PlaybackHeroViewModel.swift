import ProviderPlayback
import SwiftUI
import MagicKit

/// 播放封面区域的状态；播放变化由 Observer 转发，媒体视图由能力提供。
///
/// 通过 `HeroPlaybackCapability` / `HeroMediaCapability` 读取播放状态与渲染封面
/// （见 Capabilities 目录），不直接持有内核 `PlaybackProviding` /
/// `PlaybackMediaProviding`。
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

    /// 媒体渲染能力（Capabilities 目录收窄），`weak` 持有。
    private weak var media: (any HeroMediaCapability)?

    init(
        playback: (any HeroPlaybackCapability)?,
        media: (any HeroMediaCapability)? = nil,
        isMusicSceneActive: Bool = true
    ) {
        self.media = media
        self.currentURL = playback?.currentURL
        self.state = playback?.state ?? .idle
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
        media?.makeMediaView() ?? AnyView(EmptyView())
    }

    func localizedStateText() -> String {
        media?.localizedStateText(for: state) ?? String(describing: state)
    }

    /// 下载态的纯文案标签（不含百分比）。
    ///
    /// Hero 圆环中心已单独显示百分比，底部小字只保留「正在下载」，
    /// 避免同一屏出现两个百分比。
    func localizedDownloadingLabel() -> String {
        media?.localizedDownloadingLabel() ?? HeroFallbackText.downloading
    }
}

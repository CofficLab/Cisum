import Foundation
import ProviderPlayback
import SwiftUI
import MagicKit

/// PlaybackHero 能够发出的最小播放能力边界。
///
/// 这是插件面向 ViewModel 暴露的能力；ViewModel 不依赖 Kernel、
/// `PlaybackProviding` 或 `MagicPlayMan` 具体类型。Adapter 在
/// `PlaybackHeroPlugin` 的 onReady 阶段由内核 Provider 组装。
@MainActor
protocol PlaybackHeroPlaybackCapability: AnyObject {
    /// 当前播放资源 URL。
    var currentURL: URL? { get }

    /// 当前播放状态。
    var state: PlaybackStatus { get }

    /// 构建播放封面视图（由具体播放服务提供）。
    func makeHeroView() -> AnyView

    /// 返回指定播放状态的本地化文本。
    func localizedStateText(for state: PlaybackStatus) -> String
}

/// 将内核的 `PlaybackProviding` 适配成 PlaybackHero 的播放能力。
@MainActor
final class PlaybackHeroPlaybackCapabilityAdapter: PlaybackHeroPlaybackCapability, SuperLog {
    nonisolated static let verbose = false

    private let playback: any PlaybackProviding
    private let media: (any PlaybackMediaProviding)?

    init(playback: any PlaybackProviding, media: (any PlaybackMediaProviding)?) {
        self.playback = playback
        self.media = media
    }

    var currentURL: URL? { playback.currentURL }

    var state: PlaybackStatus { playback.state }

    func makeHeroView() -> AnyView {
        media?.makeMediaView() ?? AnyView(EmptyView())
    }

    func localizedStateText(for state: PlaybackStatus) -> String {
        media?.localizedStateText(for: state) ?? String(describing: state)
    }
}

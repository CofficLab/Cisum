import Combine

/// 播放器区「是否呈现内容」的共享布局信号（收起 150 / 展开 250）。
///
/// 由 `PluginPlaybackHero` 的 Observer 根据播放 / 场景 / 仓库事件驱动；
/// `ControlView` 与根布局（`RootLayoutView`）共同消费。
///
/// 之前该信号经 `PlaybackHeroVisibilityKey` preference 自底向上传递，
/// 实测该链路会停留在默认值（true），导致空态下播放器高度不收起。
@MainActor
public final class ControlHeroVisibility: ObservableObject {
    public static let shared = ControlHeroVisibility()

    @Published public var isVisible: Bool

    public init(isVisible: Bool = true) {
        self.isVisible = isVisible
    }
}

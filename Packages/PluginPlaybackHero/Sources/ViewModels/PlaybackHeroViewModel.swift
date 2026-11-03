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

    /// 音乐仓库是否**已确认非空**。
    ///
    /// 与 `isRepositoryEmpty` 分开的原因：仓库状态是三态的——
    /// 「还没扫过」（不知道）/「确认为空」/「确认非空」。
    /// `isRepositoryEmpty` 的初值 `false` 同时代表「还没扫过」和「确认非空」，
    /// 两者对 idle 占位的含义完全相反：只有**确认非空**才能说明
    /// 「仓库里有歌，但用户还没选」，这时候才轮到占位接手；
    /// 「还没扫过」时占位不该出现（否则启动瞬间会闪一下占位）。
    @Published private(set) var isRepositoryKnownNonEmpty = false

    var isHeroVisible: Bool {
        // Hero 只在音乐场景显示；切到其他场景（如有声书）时必须隐藏，
        // 即使 currentURL 仍保留（SceneObserver 为恢复而保留）。
        isMusicSceneActive && currentURL != nil && !isRepositoryEmpty
    }

    /// 是否呈现「无当前曲目」的占位态。
    ///
    /// 触发条件：音乐场景 + 仓库**确认非空** + **没有**当前曲目。
    ///
    /// 这是一个此前无人负责的状态：仓库非空时，空仓库引导不亮；
    /// 没有当前曲目时，真实封面与标题也不出现——控制区顶部于是整片空白
    /// （用户报告的启动态空播放器）。占位态接手这一区域，
    /// 提示用户「仓库里有歌，去选一首」。
    ///
    /// 有当前曲目时返回 `false`：真实封面与标题优先。
    /// 仓库为空时返回 `false`：那块区域归空仓库引导管（视觉语言一致）。
    var showsIdlePlaceholder: Bool {
        isMusicSceneActive && currentURL == nil && isRepositoryKnownNonEmpty
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

    /// 应用仓库空/非空结论。
    ///
    /// 「确认为空」与「确认非空」互斥：一次结论只表达一件事，
    /// 因此这里同时维护两个标记，避免旧结论残留。
    func applyRepositoryEmpty(_ isEmpty: Bool) {
        isRepositoryEmpty = isEmpty
        isRepositoryKnownNonEmpty = !isEmpty
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

import Combine
import Foundation
import MagicKit

/// 打开按钮的状态容器：只跟踪「当前播放文件」。
///
/// 经 `OpenButtonCapability` 读取播放状态（见 Capabilities 目录），
/// 不直接持有内核 `PlaybackProviding`。
@MainActor
final class OpenButtonViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var url: URL?
    /// 播放能力（Capabilities 目录收窄）。
    ///
    /// **强持有**：入口 teardown 先释放本容器再释放能力；能力内部对 Provider
    /// 为 `weak`，强持有能力不会延长播放 Provider 的生命周期。
    private let playback: (any OpenButtonCapability)?

    init(playback: (any OpenButtonCapability)?) {
        self.playback = playback
        url = playback?.currentURL
    }

    func handleAssetChanged(_ url: URL?) {
        self.url = url
    }
}

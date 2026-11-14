import Foundation
import ProviderAudioNavigation

/// 曲目导航能力：按播放顺序查询相邻曲目。
///
/// 内核 `AudioTrackNavigationProviding` 的 4 个方法全部被控制按钮消费
/// （上一曲/下一曲/首曲/尾曲，用于「单曲循环」时首尾回绕），此处原样收窄，
/// 仅剥除 `verbose` 参数的默认值重载。
@MainActor
protocol TrackNavigationCapability: AnyObject {
    /// 获取当前曲目之后的曲目；已是最后一首时返回 `nil`。
    func nextURL(after current: URL) async throws -> URL?

    /// 获取当前曲目之前的曲目；已是第一首时返回 `nil`。
    func previousURL(before current: URL) async throws -> URL?

    /// 获取音频库中的第一首曲目；空库时返回 `nil`。
    func firstURL() async throws -> URL?

    /// 获取音频库中的最后一首曲目；空库时返回 `nil`。
    func lastURL() async throws -> URL?
}

/// 将内核 `AudioTrackNavigationProviding` 收窄为控制按钮的曲目导航能力。
@MainActor
final class TrackNavigationCapabilityAdapter: TrackNavigationCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时导航方法退化并由 ViewModel 提示「导航服务不可用」。
    private weak var navigation: (any AudioTrackNavigationProviding)?

    init(navigation: (any AudioTrackNavigationProviding)?) {
        self.navigation = navigation
    }

    func nextURL(after current: URL) async throws -> URL? {
        try await navigation?.nextURL(after: current, verbose: true)
    }

    func previousURL(before current: URL) async throws -> URL? {
        try await navigation?.previousURL(before: current, verbose: true)
    }

    func firstURL() async throws -> URL? {
        try await navigation?.firstURL()
    }

    func lastURL() async throws -> URL? {
        try await navigation?.lastURL()
    }
}
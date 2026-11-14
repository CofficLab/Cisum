import Foundation
import ProviderAudioNavigation

/// Widget 曲目导航能力。
///
/// 内核 `AudioTrackNavigationProviding` 的 4 个方法全部被 Widget 的
/// 「上一曲/下一曲 + 单曲循环时首尾回绕」消费，此处原样收窄。
///
/// 收窄的收益：原本入口要向 ViewModel 注入 4 个各自 `resolveProvider` 的闭包，
/// 重复解析逻辑分散在装配层；改为单个能力后，Provider 解析与降级语义
/// 收敛到一处，ViewModel 只面对一个明确的依赖。
@MainActor
protocol WidgetNavigationCapability: AnyObject {
    /// 获取当前曲目之后的曲目；已是最后一首时返回 `nil`。
    func nextURL(after current: URL) async throws -> URL?

    /// 获取当前曲目之前的曲目；已是第一首时返回 `nil`。
    func previousURL(before current: URL) async throws -> URL?

    /// 获取音频库中的第一首曲目；空库时返回 `nil`。
    func firstURL() async throws -> URL?

    /// 获取音频库中的最后一首曲目；空库时返回 `nil`。
    func lastURL() async throws -> URL?
}

/// 将内核 `AudioTrackNavigationProviding` 收窄为 Widget 的曲目导航能力。
@MainActor
final class WidgetNavigationCapabilityAdapter: WidgetNavigationCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时导航退化并由 ViewModel 放弃该次回绕。
    private weak var navigation: (any AudioTrackNavigationProviding)?

    init(navigation: (any AudioTrackNavigationProviding)?) {
        self.navigation = navigation
    }

    func nextURL(after current: URL) async throws -> URL? {
        try await navigation?.nextURL(after: current, verbose: false)
    }

    func previousURL(before current: URL) async throws -> URL? {
        try await navigation?.previousURL(before: current, verbose: false)
    }

    func firstURL() async throws -> URL? {
        try await navigation?.firstURL()
    }

    func lastURL() async throws -> URL? {
        try await navigation?.lastURL()
    }
}
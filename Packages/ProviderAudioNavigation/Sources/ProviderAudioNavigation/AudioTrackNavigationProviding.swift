import Foundation

/// 音频库中的上一首/下一首能力。
///
/// Provider 只负责定义导航边界和调用约定，不负责播放。消费方拿到目标 URL
/// 后，再通过 `PlaybackProviding` 播放；具体数据源由实现该 Provider 的插件注入。
@MainActor
public protocol AudioTrackNavigationProviding: AnyObject {
    /// 获取当前曲目之后的曲目。
    func nextURL(after current: URL?, verbose: Bool) async throws -> URL?

    /// 获取当前曲目之前的曲目。
    func previousURL(before current: URL?, verbose: Bool) async throws -> URL?

    /// 获取音频库中的第一首曲目。
    func firstURL() async throws -> URL?

    /// 获取音频库中的最后一首曲目。
    func lastURL() async throws -> URL?
}

public extension AudioTrackNavigationProviding {
    func nextURL(after current: URL?) async throws -> URL? {
        try await nextURL(after: current, verbose: false)
    }

    func previousURL(before current: URL?) async throws -> URL? {
        try await previousURL(before: current, verbose: false)
    }
}
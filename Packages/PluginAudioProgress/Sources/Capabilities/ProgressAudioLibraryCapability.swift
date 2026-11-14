import Foundation
import ProviderAudioLibrary

/// 进度恢复所需的最小音频库能力。
///
/// 内核 `AudioLibraryProviding` 的写入能力（`delete` / `sync` / `sort` /
/// `sortRandom`）本插件不消费；`contains` / `allURLs` 仅用于「恢复上次播放」
/// 这一处逻辑，故在此收窄。
///
/// ## 惰性解析
/// 数据层插件的 boot 顺序不确定，进度条的恢复可能早于 `AudioLibraryProviding`
/// 注册。能力内部持**惰性解析闭包**：Provider 稍后就绪时自动生效，无需重建
/// ViewModel，也无需在 `onReady` 重新绑定。
@MainActor
protocol ProgressAudioLibraryCapability: AnyObject, Sendable {
    /// 能力是否已绑定到可用的 Provider。
    ///
    /// 用于区分「Provider 未就绪」（应放弃本次恢复并提示）与
    /// 「已就绪但库为空」（可安全回落到第一首曲目）。
    var isAvailable: Bool { get }

    /// 判断 URL 是否存在于音频库中。
    func contains(_ url: URL) async -> Bool

    /// 按稳定播放顺序读取全部音频 URL。
    func allURLs(reason: String) async -> [URL]
}

/// 将内核 `AudioLibraryProviding` 收窄为进度恢复的音频库能力。
@MainActor
final class ProgressAudioLibraryCapabilityAdapter: ProgressAudioLibraryCapability {
    private let resolve: @MainActor @Sendable () -> (any AudioLibraryProviding)?

    init(resolve: @escaping @MainActor @Sendable () -> (any AudioLibraryProviding)?) {
        self.resolve = resolve
    }

    /// 当前可用的 Provider；尚未注册时为 `nil`。
    var isAvailable: Bool { resolve() != nil }

    func contains(_ url: URL) async -> Bool {
        await resolve()?.contains(url) ?? false
    }

    func allURLs(reason: String) async -> [URL] {
        await resolve()?.allURLs(reason: reason) ?? []
    }
}
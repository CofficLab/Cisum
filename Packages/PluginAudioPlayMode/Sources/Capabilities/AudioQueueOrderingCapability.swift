import Foundation
import ProviderAudioLibrary

/// 音频播放队列排序能力。
///
/// 收窄自内核 `AudioLibraryOrderingProviding`：播放模式切换到「顺序」或「随机」
/// 时，需要按新顺序重建播放队列。
///
/// 收窄的实际收益：入口原先用 `makeSortAction()` / `makeShuffleAction()` 两个
/// 闭包各自在内部 `resolveProvider(AudioLibraryOrderingProviding.self)`，解析与
/// 「Provider 未就绪则抛错」的降级语义重复两份；收敛到本能力后由 Adapter 统一承担。
@MainActor
protocol AudioQueueOrderingCapability: AnyObject {
    /// 按当前顺序重排播放队列；`currentURL` 用于保持当前曲目位置。
    func sort(currentURL: URL?) async throws

    /// 随机重排播放队列；`currentURL` 用于保持当前曲目位置。
    func shuffle(currentURL: URL?) async throws
}

/// 将内核 `AudioLibraryOrderingProviding` 收窄为播放队列排序能力。
///
/// 诊断字符串 `reason` 属于 Provider 的观测细节，由 Adapter 统一携带，
/// 调用方无需感知。
@MainActor
final class AudioQueueOrderingCapabilityAdapter: AudioQueueOrderingCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化并由 ViewModel 提示「队列不可用」。
    private weak var ordering: (any AudioLibraryOrderingProviding)?

    init(ordering: (any AudioLibraryOrderingProviding)?) {
        self.ordering = ordering
    }

    func sort(currentURL: URL?) async throws {
        guard let ordering else {
            throw AudioLibraryProvidingError.unavailable
        }
        await ordering.sort(url: currentURL, reason: "PlayModeChanged")
    }

    func shuffle(currentURL: URL?) async throws {
        guard let ordering else {
            throw AudioLibraryProvidingError.unavailable
        }
        try await ordering.sortRandom(url: currentURL, reason: "PlayModeChanged", verbose: false)
    }
}
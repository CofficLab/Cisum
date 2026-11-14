import Foundation
import ProviderAudioLibrary

/// 复制任务所需的最小音频库能力。
///
/// 内核 `AudioLibraryProviding` 的播放、删除、排序等能力复制功能均不消费，
/// 只需要「磁盘目录（复制目标）+ 仓库总数（进度/空库判断）」。
///
/// ## 惰性解析
/// 入口原先注入两个闭包，各自在每次调用时 `resolveProvider`；能力内部统一持
/// 惰性解析闭包，解析语义收敛一处，服务侧只面对一个明确的依赖。
@MainActor
protocol AudioCopyLibraryCapability: AnyObject, Sendable {
    /// 音频磁盘目录；尚未配置时为 `nil`。
    var audioDisk: URL? { get }

    /// 当前音频库中的项目数量。
    func totalCount() async -> Int
}

/// 将内核 `AudioLibraryProviding` 收窄为复制功能的音频库能力。
@MainActor
final class AudioCopyLibraryCapabilityAdapter: AudioCopyLibraryCapability {
    private let resolve: @MainActor @Sendable () -> (any AudioLibraryProviding)?

    init(resolve: @escaping @MainActor @Sendable () -> (any AudioLibraryProviding)?) {
        self.resolve = resolve
    }

    /// 当前可用的 Provider；尚未注册时为 `nil`。
    var isAvailable: Bool { resolve() != nil }

    var audioDisk: URL? { resolve()?.audioDisk }

    func totalCount() async -> Int {
        await resolve()?.totalCount() ?? 0
    }
}
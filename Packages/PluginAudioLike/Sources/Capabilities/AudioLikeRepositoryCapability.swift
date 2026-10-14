import Foundation
import ProviderAudioLike

/// 音频喜欢仓库能力：喜欢列表的读取与喜欢状态的保存。
///
/// 本插件是 `AudioLikeProviding` 的**生产方**（自己注册 Provider），但设置页与
/// 状态保存是它的**消费方**——两端分离，因此消费侧同样需要收窄。
///
/// ## 惰性解析
/// Provider 由本插件在 boot 阶段注册，而设置页的 View 贡献可能在 Provider
/// 注册之前被请求；原入口的两个闭包各自在每次调用时 `resolveProvider`，
/// 解析语义重复两份。能力内部统一持惰性解析闭包，Provider 就绪后自动生效。
@MainActor
protocol AudioLikeRepositoryCapability: AnyObject, Sendable {
    /// 读取全部喜欢的音频。
    func allLiked() async -> [AudioLikeItem]

    /// 保存/更新喜欢状态；`liked` 为 `false` 表示取消喜欢。
    func updateLikeStatus(
        audioId: String,
        liked: Bool,
        url: URL?,
        title: String?
    ) async throws
}

/// 将内核 `AudioLikeProviding` 收窄为喜欢仓库能力。
@MainActor
final class AudioLikeRepositoryCapabilityAdapter: AudioLikeRepositoryCapability {
    private let resolve: @MainActor @Sendable () -> (any AudioLikeProviding)?

    init(resolve: @escaping @MainActor @Sendable () -> (any AudioLikeProviding)?) {
        self.resolve = resolve
    }

    /// 当前可用的 Provider；尚未注册时为 `nil`。
    var isAvailable: Bool { resolve() != nil }

    func allLiked() async -> [AudioLikeItem] {
        await resolve()?.allLiked() ?? []
    }

    func updateLikeStatus(
        audioId: String,
        liked: Bool,
        url: URL?,
        title: String?
    ) async throws {
        try await resolve()?.updateLikeStatus(
            audioId: audioId,
            liked: liked,
            url: url,
            title: title
        )
    }
}
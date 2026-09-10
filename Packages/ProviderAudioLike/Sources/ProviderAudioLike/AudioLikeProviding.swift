import Foundation

/// 跨插件传递的喜欢条目；不暴露 SwiftData 模型。
public struct AudioLikeItem: Identifiable, Sendable, Equatable {
    public let audioId: String
    public let url: URL?
    public let title: String?
    public let liked: Bool

    public var id: String { audioId }

    public init(audioId: String, url: URL?, title: String?, liked: Bool) {
        self.audioId = audioId
        self.url = url
        self.title = title
        self.liked = liked
    }
}

/// 音频喜欢能力协议。
///
/// Provider 包只定义调用边界和 DTO；SwiftData、数据库路径和去重逻辑由
/// `PluginAudioLike` 负责组装和实现。
@MainActor
public protocol AudioLikeProviding: AnyObject, Sendable {
    func isLiked(url: URL) async -> Bool
    func allLiked() async -> [AudioLikeItem]
    func updateLikeStatus(
        audioId: String,
        liked: Bool,
        url: URL?,
        title: String?
    ) async throws
}

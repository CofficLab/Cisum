import Foundation
import SwiftData
import SwiftUI

/**
 音频喜欢状态数据模型

 用于独立存储音频的喜欢状态
 */
@Model
class AudioLikeModel {
    /// 音频的唯一标识符
    var audioId: String

    /// 音频的 URL
    var url: URL?

    /// 是否喜欢
    var liked: Bool = false

    /// 创建时间
    var createdAt: Date = Date()

    /// 更新时间
    var updatedAt: Date = Date()

    /// 音频标题（用于显示）
    var title: String?

    init(audioId: String, url: URL?, title: String? = nil, liked: Bool = false) {
        self.audioId = audioId
        self.url = url
        self.title = title
        self.liked = liked
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Fetch Descriptors

extension AudioLikeModel {
    /// 获取所有喜欢状态的描述符
    static let descriptorAll = FetchDescriptor<AudioLikeModel>(
        predicate: #Predicate<AudioLikeModel> { _ in true },
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )

    /// 根据音频 ID 获取喜欢状态的描述符
    static func descriptorOf(audioId: String) -> FetchDescriptor<AudioLikeModel> {
        FetchDescriptor<AudioLikeModel>(
            predicate: #Predicate<AudioLikeModel> { model in
                model.audioId == audioId
            }
        )
    }

    /// 根据 URL 获取喜欢状态的描述符
    static func descriptorOf(url: URL) -> FetchDescriptor<AudioLikeModel> {
        FetchDescriptor<AudioLikeModel>(
            predicate: #Predicate<AudioLikeModel> { model in
                model.url == url
            }
        )
    }

    /// 获取所有已喜欢的音频
    static let descriptorLiked = FetchDescriptor<AudioLikeModel>(
        predicate: #Predicate<AudioLikeModel> { model in
            model.liked == true
        },
        sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
    )
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

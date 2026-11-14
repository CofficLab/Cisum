import Foundation
import SwiftData

@Model
public final class AudioLikeModel {
    public var audioId: String
    public var url: URL?
    public var liked: Bool = false
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var title: String?

    public init(audioId: String, url: URL?, title: String? = nil, liked: Bool = false) {
        self.audioId = audioId
        self.url = url
        self.title = title
        self.liked = liked
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

public extension AudioLikeModel {
    static let descriptorAll = FetchDescriptor<AudioLikeModel>(
        predicate: #Predicate<AudioLikeModel> { _ in true },
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )

    static func descriptorOf(audioId: String) -> FetchDescriptor<AudioLikeModel> {
        FetchDescriptor<AudioLikeModel>(
            predicate: #Predicate<AudioLikeModel> { model in
                model.audioId == audioId
            }
        )
    }

    static func descriptorOf(url: URL) -> FetchDescriptor<AudioLikeModel> {
        FetchDescriptor<AudioLikeModel>(
            predicate: #Predicate<AudioLikeModel> { model in
                model.url == url
            }
        )
    }

    static let descriptorLiked = FetchDescriptor<AudioLikeModel>(
        predicate: #Predicate<AudioLikeModel> { model in
            model.liked == true
        },
        sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
    )
}

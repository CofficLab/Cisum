import Combine
import Foundation
import MagicKit
import ProviderPlayback

@MainActor
final class OpenButtonViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var url: URL?
    private let playbackProvider: (any PlaybackProviding)?

    init(playbackProvider: (any PlaybackProviding)?) {
        self.playbackProvider = playbackProvider
        url = playbackProvider?.currentURL
    }

    func handleAssetChanged(_ url: URL?) {
        self.url = url
    }
}

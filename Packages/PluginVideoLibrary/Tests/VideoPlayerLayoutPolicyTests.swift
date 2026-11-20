import CoreGraphics
import Foundation
import Testing
@testable import PluginVideoLibrary

struct VideoPlayerLayoutPolicyTests {
    @Test("只有仓库可用且存在视频时才呈现 Hero")
    func heroVisibility() {
        let repository = URL(fileURLWithPath: "/tmp/videos")

        #expect(!VideoPlayerLayoutPolicy.isHeroVisible(repositoryURL: nil, itemCount: 0))
        #expect(!VideoPlayerLayoutPolicy.isHeroVisible(repositoryURL: repository, itemCount: 0))
        #expect(!VideoPlayerLayoutPolicy.isHeroVisible(repositoryURL: nil, itemCount: 1))
        #expect(VideoPlayerLayoutPolicy.isHeroVisible(repositoryURL: repository, itemCount: 1))
    }

    @Test("播放画面在可用空间内保持 16:9")
    func playerSize() {
        #expect(VideoPlayerLayoutPolicy.playerSize(in: CGSize(width: 320, height: 320)) == CGSize(width: 320, height: 180))
        #expect(VideoPlayerLayoutPolicy.playerSize(in: CGSize(width: 800, height: 90)) == CGSize(width: 160, height: 90))
        #expect(VideoPlayerLayoutPolicy.playerSize(in: .zero) == .zero)
    }
}

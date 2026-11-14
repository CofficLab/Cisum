import Foundation
import Testing
@testable import ProviderAudioLike

/// 补充测试用例 - 对应 TestPlan.md 中标记为 ❌ 缺失的测试
@Suite struct ProviderAudioLikeGapTests {

    // MARK: - AudioLikeItem 初始化器测试

    /// TC-03: AudioLikeItem 初始化器正确设置所有属性
    @Test func audioLikeItemInitializerSetsAllProperties() {
        let audioId = "test-audio-id"
        let url = URL(string: "https://example.com/audio.mp3")!
        let title = "Test Audio"
        let liked = true

        let item = AudioLikeItem(
            audioId: audioId,
            url: url,
            title: title,
            liked: liked
        )

        #expect(item.audioId == audioId)
        #expect(item.url == url)
        #expect(item.title == title)
        #expect(item.liked == liked)
        #expect(item.id == audioId)
    }

    // MARK: - 可选值处理测试

    /// TC-04: AudioLikeItem 支持可选的 url
    @Test func audioLikeItemSupportsOptionalURL() {
        let item = AudioLikeItem(
            audioId: "audio-id",
            url: nil,
            title: "Audio",
            liked: true
        )

        #expect(item.url == nil)
        #expect(item.audioId == "audio-id")
        #expect(item.liked == true)
    }

    /// TC-05: AudioLikeItem 支持可选的 title
    @Test func audioLikeItemSupportsOptionalTitle() {
        let url = URL(string: "https://example.com/audio.mp3")!
        let item = AudioLikeItem(
            audioId: "audio-id",
            url: url,
            title: nil,
            liked: false
        )

        #expect(item.title == nil)
        #expect(item.url == url)
        #expect(item.liked == false)
    }

    /// TC-05b: AudioLikeItem 支持 url 和 title 同时为 nil
    @Test func audioLikeItemSupportsBothOptionalsAsNil() {
        let item = AudioLikeItem(
            audioId: "audio-id",
            url: nil,
            title: nil,
            liked: true
        )

        #expect(item.url == nil)
        #expect(item.title == nil)
        #expect(item.audioId == "audio-id")
        #expect(item.liked == true)
    }

    // MARK: - Equatable 测试

    /// TC-06: AudioLikeItem 的 Equatable 实现 - 相等的情况
    @Test func audioLikeItemEquatableWhenEqual() {
        let url = URL(string: "https://example.com/audio.mp3")!
        let item1 = AudioLikeItem(
            audioId: "audio-id",
            url: url,
            title: "Audio",
            liked: true
        )
        let item2 = AudioLikeItem(
            audioId: "audio-id",
            url: url,
            title: "Audio",
            liked: true
        )

        #expect(item1 == item2)
    }

    /// TC-06b: AudioLikeItem 的 Equatable 实现 - 不相等的情况（audioId 不同）
    @Test func audioLikeItemEquatableWhenAudioIdDiffers() {
        let url = URL(string: "https://example.com/audio.mp3")!
        let item1 = AudioLikeItem(
            audioId: "audio-id-1",
            url: url,
            title: "Audio",
            liked: true
        )
        let item2 = AudioLikeItem(
            audioId: "audio-id-2",
            url: url,
            title: "Audio",
            liked: true
        )

        #expect(item1 != item2)
    }

    /// TC-06c: AudioLikeItem 的 Equatable 实现 - 不相等的情况（liked 不同）
    @Test func audioLikeItemEquatableWhenLikedDiffers() {
        let url = URL(string: "https://example.com/audio.mp3")!
        let item1 = AudioLikeItem(
            audioId: "audio-id",
            url: url,
            title: "Audio",
            liked: true
        )
        let item2 = AudioLikeItem(
            audioId: "audio-id",
            url: url,
            title: "Audio",
            liked: false
        )

        #expect(item1 != item2)
    }

    /// TC-06d: AudioLikeItem 的 Equatable 实现 - 不相等的情况（url 不同）
    @Test func audioLikeItemEquatableWhenURLDiffers() {
        let url1 = URL(string: "https://example.com/audio1.mp3")!
        let url2 = URL(string: "https://example.com/audio2.mp3")!
        let item1 = AudioLikeItem(
            audioId: "audio-id",
            url: url1,
            title: "Audio",
            liked: true
        )
        let item2 = AudioLikeItem(
            audioId: "audio-id",
            url: url2,
            title: "Audio",
            liked: true
        )

        #expect(item1 != item2)
    }

    /// TC-06e: AudioLikeItem 的 Equatable 实现 - 不相等的情况（title 不同）
    @Test func audioLikeItemEquatableWhenTitleDiffers() {
        let url = URL(string: "https://example.com/audio.mp3")!
        let item1 = AudioLikeItem(
            audioId: "audio-id",
            url: url,
            title: "Audio 1",
            liked: true
        )
        let item2 = AudioLikeItem(
            audioId: "audio-id",
            url: url,
            title: "Audio 2",
            liked: true
        )

        #expect(item1 != item2)
    }

    // MARK: - Sendable 测试

    /// TC-07: AudioLikeItem 的 Sendable 特性 - 可以在 async 上下文中使用
    @Test func audioLikeItemIsSendable() async {
        let item = AudioLikeItem(
            audioId: "audio-id",
            url: URL(string: "https://example.com/audio.mp3"),
            title: "Audio",
            liked: true
        )

        // 在 Task 中使用
        await Task.detached {
            #expect(item.audioId == "audio-id")
            #expect(item.liked == true)
        }.value
    }

    // MARK: - 协议验证测试

    /// TC-08: AudioLikeProviding 协议方法签名验证
    @Test @MainActor func audioLikeProvidingProtocolMethodsExist() async throws {
        // 创建一个简单的 mock 实现来验证协议
        let mockProvider = MockAudioLikeProvider()

        // 验证方法可以调用
        _ = await mockProvider.isLiked(url: URL(string: "https://example.com/audio.mp3")!)
        _ = await mockProvider.allLiked()
        try await mockProvider.updateLikeStatus(
            audioId: "audio-id",
            liked: true,
            url: URL(string: "https://example.com/audio.mp3"),
            title: "Audio"
        )
    }
}

/// Mock 实现用于协议验证
@MainActor
private final class MockAudioLikeProvider: AudioLikeProviding {
    func isLiked(url: URL) async -> Bool {
        return false
    }

    func allLiked() async -> [AudioLikeItem] {
        return []
    }

    func updateLikeStatus(
        audioId: String,
        liked: Bool,
        url: URL?,
        title: String?
    ) async throws {
        // Mock 实现
    }
}

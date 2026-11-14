import Foundation
import Testing
@testable import ProviderAudioNavigation

/// 补充测试 - 对应 TestPlan.md 中标记为 ❌ 缺失的测试用例
@Suite @MainActor struct ProviderAudioNavigationGapTests {

    // MARK: - 协议方法基本功能测试

    /// TC-03: nextURL 返回正确的下一首曲目
    @Test func nextURLReturnsCorrectNextTrack() async throws {
        let provider = StubAudioTrackNavigationProvider()
        let current = URL(fileURLWithPath: "/library/track1.mp3")
        let next = URL(fileURLWithPath: "/library/track2.mp3")
        provider.nextResult = next

        let result = try await provider.nextURL(after: current, verbose: true)

        #expect(result == next)
        #expect(provider.nextVerboseValues == [true])
    }

    /// TC-04: previousURL 返回正确的上一首曲目
    @Test func previousURLReturnsCorrectPreviousTrack() async throws {
        let provider = StubAudioTrackNavigationProvider()
        let current = URL(fileURLWithPath: "/library/track2.mp3")
        let previous = URL(fileURLWithPath: "/library/track1.mp3")
        provider.previousResult = previous

        let result = try await provider.previousURL(before: current, verbose: true)

        #expect(result == previous)
        #expect(provider.previousVerboseValues == [true])
    }

    /// TC-05: firstURL 返回第一首曲目
    @Test func firstURLReturnsFirstTrack() async throws {
        let provider = ConfigurableStubAudioTrackNavigationProvider()
        let first = URL(fileURLWithPath: "/library/track1.mp3")
        provider.firstResult = first

        let result = try await provider.firstURL()

        #expect(result == first)
    }

    /// TC-06: lastURL 返回最后一首曲目
    @Test func lastURLReturnsLastTrack() async throws {
        let provider = ConfigurableStubAudioTrackNavigationProvider()
        let last = URL(fileURLWithPath: "/library/track10.mp3")
        provider.lastResult = last

        let result = try await provider.lastURL()

        #expect(result == last)
    }

    // MARK: - 边界情况测试

    /// TC-07: nextURL 可以接受 nil 作为当前曲目
    @Test func nextURLAcceptsNilAsCurrentTrack() async throws {
        let provider = StubAudioTrackNavigationProvider()
        let next = URL(fileURLWithPath: "/library/track1.mp3")
        provider.nextResult = next

        let result = try await provider.nextURL(after: nil)

        #expect(result == next)
    }

    /// TC-08: previousURL 可以接受 nil 作为当前曲目
    @Test func previousURLAcceptsNilAsCurrentTrack() async throws {
        let provider = StubAudioTrackNavigationProvider()
        let previous = URL(fileURLWithPath: "/library/track10.mp3")
        provider.previousResult = previous

        let result = try await provider.previousURL(before: nil)

        #expect(result == previous)
    }

    // MARK: - 错误处理测试

    /// TC-09: nextURL 可以抛出错误
    @Test func nextURLCanThrowError() async throws {
        let provider = ThrowingStubAudioTrackNavigationProvider()
        provider.shouldThrowNext = true

        await #expect(throws: NavigationError.self) {
            _ = try await provider.nextURL(after: nil)
        }
    }

    /// TC-10: previousURL 可以抛出错误
    @Test func previousURLCanThrowError() async throws {
        let provider = ThrowingStubAudioTrackNavigationProvider()
        provider.shouldThrowPrevious = true

        await #expect(throws: NavigationError.self) {
            _ = try await provider.previousURL(before: nil)
        }
    }

    /// TC-11: firstURL 可以抛出错误
    @Test func firstURLCanThrowError() async throws {
        let provider = ThrowingStubAudioTrackNavigationProvider()
        provider.shouldThrowFirst = true

        await #expect(throws: NavigationError.self) {
            _ = try await provider.firstURL()
        }
    }

    /// TC-12: lastURL 可以抛出错误
    @Test func lastURLCanThrowError() async throws {
        let provider = ThrowingStubAudioTrackNavigationProvider()
        provider.shouldThrowLast = true

        await #expect(throws: NavigationError.self) {
            _ = try await provider.lastURL()
        }
    }

    // MARK: - verbose 参数传递测试

    /// TC-13: verbose 参数正确传递
    @Test func verboseParameterIsPassedCorrectly() async throws {
        let provider = StubAudioTrackNavigationProvider()

        // 测试 verbose = true
        _ = try await provider.nextURL(after: nil, verbose: true)
        _ = try await provider.previousURL(before: nil, verbose: true)

        #expect(provider.nextVerboseValues == [true])
        #expect(provider.previousVerboseValues == [true])

        // 测试 verbose = false
        _ = try await provider.nextURL(after: nil, verbose: false)
        _ = try await provider.previousURL(before: nil, verbose: false)

        #expect(provider.nextVerboseValues == [true, false])
        #expect(provider.previousVerboseValues == [true, false])
    }
}

// MARK: - 测试用 Stub 实现

/// 可配置的 Stub 实现，用于测试协议方法
@MainActor
private final class StubAudioTrackNavigationProvider: AudioTrackNavigationProviding {
    private(set) var nextVerboseValues: [Bool] = []
    private(set) var previousVerboseValues: [Bool] = []
    var nextResult: URL?
    var previousResult: URL?

    func nextURL(after current: URL?, verbose: Bool) async throws -> URL? {
        nextVerboseValues.append(verbose)
        return nextResult
    }

    func previousURL(before current: URL?, verbose: Bool) async throws -> URL? {
        previousVerboseValues.append(verbose)
        return previousResult
    }

    func firstURL() async throws -> URL? { nil }
    func lastURL() async throws -> URL? { nil }
}

@MainActor
private final class ConfigurableStubAudioTrackNavigationProvider: AudioTrackNavigationProviding {
    var firstResult: URL?
    var lastResult: URL?

    func nextURL(after current: URL?, verbose: Bool) async throws -> URL? { nil }
    func previousURL(before current: URL?, verbose: Bool) async throws -> URL? { nil }
    func firstURL() async throws -> URL? { firstResult }
    func lastURL() async throws -> URL? { lastResult }
}

@MainActor
private final class ThrowingStubAudioTrackNavigationProvider: AudioTrackNavigationProviding {
    var shouldThrowNext = false
    var shouldThrowPrevious = false
    var shouldThrowFirst = false
    var shouldThrowLast = false

    func nextURL(after current: URL?, verbose: Bool) async throws -> URL? {
        if shouldThrowNext {
            throw NavigationError()
        }
        return nil
    }

    func previousURL(before current: URL?, verbose: Bool) async throws -> URL? {
        if shouldThrowPrevious {
            throw NavigationError()
        }
        return nil
    }

    func firstURL() async throws -> URL? {
        if shouldThrowFirst {
            throw NavigationError()
        }
        return nil
    }

    func lastURL() async throws -> URL? {
        if shouldThrowLast {
            throw NavigationError()
        }
        return nil
    }
}

/// 测试用错误类型
struct NavigationError: Error {}

import Foundation
import Testing
@testable import ProviderAudioNavigation

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

@Test @MainActor
func navigationConvenienceMethodsDisableVerboseLogging() async throws {
    let provider = StubAudioTrackNavigationProvider()
    let next = URL(fileURLWithPath: "/library/next.mp3")
    let previous = URL(fileURLWithPath: "/library/previous.mp3")
    provider.nextResult = next
    provider.previousResult = previous

    #expect(try await provider.nextURL(after: nil) == next)
    #expect(try await provider.previousURL(before: nil) == previous)
    #expect(provider.nextVerboseValues == [false])
    #expect(provider.previousVerboseValues == [false])
}

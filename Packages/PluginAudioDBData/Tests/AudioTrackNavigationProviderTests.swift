import Foundation
import Testing
@testable import PluginAudioDBData

private enum NavigationProviderTestError: Error {
    case expected
}

@MainActor
private final class NavigationCallRecorder {
    var next: (URL?, Bool)?
    var previous: (URL?, Bool)?
    var firstCalls = 0
    var lastCalls = 0
}

@Suite(.serialized)
@MainActor
struct AudioTrackNavigationProviderTests {
    @Test
    func forwardsArgumentsAndReturnsResolvedURLs() async throws {
        let recorder = NavigationCallRecorder()
        let current = URL(fileURLWithPath: "/library/current.mp3")
        let next = URL(fileURLWithPath: "/library/next.mp3")
        let previous = URL(fileURLWithPath: "/library/previous.mp3")
        let first = URL(fileURLWithPath: "/library/first.mp3")
        let last = URL(fileURLWithPath: "/library/last.mp3")
        let provider = AudioTrackNavigationProvider(
            nextURL: { url, verbose in
                recorder.next = (url, verbose)
                return next
            },
            previousURL: { url, verbose in
                recorder.previous = (url, verbose)
                return previous
            },
            firstURL: {
                recorder.firstCalls += 1
                return first
            },
            lastURL: {
                recorder.lastCalls += 1
                return last
            }
        )

        #expect(try await provider.nextURL(after: current, verbose: true) == next)
        #expect(try await provider.previousURL(before: current, verbose: false) == previous)
        #expect(try await provider.firstURL() == first)
        #expect(try await provider.lastURL() == last)
        #expect(recorder.next?.0 == current)
        #expect(recorder.next?.1 == true)
        #expect(recorder.previous?.0 == current)
        #expect(recorder.previous?.1 == false)
        #expect(recorder.firstCalls == 1)
        #expect(recorder.lastCalls == 1)
    }

    @Test
    func propagatesResolverErrorsWithoutChangingThem() async {
        let provider = AudioTrackNavigationProvider(
            nextURL: { _, _ in throw NavigationProviderTestError.expected },
            previousURL: { _, _ in throw NavigationProviderTestError.expected },
            firstURL: { throw NavigationProviderTestError.expected },
            lastURL: { throw NavigationProviderTestError.expected }
        )

        await #expect(throws: NavigationProviderTestError.self) {
            try await provider.nextURL(after: nil, verbose: false)
        }
        await #expect(throws: NavigationProviderTestError.self) {
            try await provider.previousURL(before: nil, verbose: false)
        }
        await #expect(throws: NavigationProviderTestError.self) {
            try await provider.firstURL()
        }
        await #expect(throws: NavigationProviderTestError.self) {
            try await provider.lastURL()
        }
    }
}

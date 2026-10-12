import Foundation
import Testing
@testable import ProviderAudioLibrary

@MainActor
private final class StubAudioLibraryProvider: AudioLibraryProviding {
    var audioDisk: URL? { nil }
    var supportedExtensions: [String] { [] }
    var isAvailable: Bool { false }

    func totalCount() async -> Int { 0 }
    func allURLs(reason: String) async -> [URL] { [] }
    func urls(offset: Int, limit: Int, reason: String) async -> [URL] { [] }
    func contains(_ url: URL) async -> Bool { false }
    func delete(urls: [URL], verbose: Bool) async throws {}
    func sync(urls: [URL], verbose: Bool, isFirst: Bool) async {}
    func sort(url: URL?, reason: String) async {}
    func sortRandom(url: URL?, reason: String, verbose: Bool) async throws {}
}

@Test @MainActor
func audioLibraryDefaultObserverReturnsNoopHandle() {
    let provider = StubAudioLibraryProvider()
    let handle = provider.addObserver { _ in
        Issue.record("The default observer must not receive events")
    }

    #expect(handle is NoopAudioLibraryProvidingObserverHandle)
    handle.cancel()
    handle.cancel()
}

@Test
func unavailableLibraryErrorIsTransportSafe() {
    let error = AudioLibraryProvidingError.unavailable
    guard case .unavailable = error else {
        Issue.record("Expected the unavailable library error")
        return
    }
}

@Test
func audioPluginInfoUsesBuildSpecificRepositoryDirectory() {
    #if DEBUG
        #expect(AudioPluginInfo.effectiveDBDirName == AudioPluginInfo.debugDBDirName)
    #else
        #expect(AudioPluginInfo.effectiveDBDirName == AudioPluginInfo.dbDirName)
    #endif
    #expect(AudioPluginInfo.supportedExtensions == [
        "mp3", "m4a", "aac", "aiff", "flac", "wav", "ogg", "opus", "alac",
    ])
    #expect(AudioPluginInfo.maxAudioCount > 0)
}

@Test
func audioStorageDiagnosticsExplainsUnavailableRepository() {
    let cases: [(
        location: String?,
        isICloudAvailable: Bool,
        hasUsableStorageLocation: Bool,
        cloudContainer: String?,
        cloudDocuments: String?,
        localDocuments: String?,
        storageRoot: String?,
        audioDisk: String?,
        expectedReason: String
    )] = [
        (nil, false, false, nil, nil, nil, nil, nil, "Storage location is not set. Go to Storage settings and choose iCloud or Local."),
        ("icloud", false, true, nil, nil, nil, nil, nil, "iCloud is not available on this device (not signed in or not authorized)."),
        ("icloud", true, true, nil, nil, nil, nil, nil, "iCloud container could not be resolved (ubiquity container URL is nil)."),
        ("local", true, true, nil, nil, nil, nil, nil, "Storage root could not be resolved for location 'local'."),
        ("local", true, true, nil, nil, nil, "/Documents", nil, "Audio repository directory could not be created at storage root."),
    ]

    for testCase in cases {
        let diagnostics = AudioStorageDiagnostics(
            storageLocationRaw: testCase.location,
            isICloudAvailable: testCase.isICloudAvailable,
            hasUsableStorageLocation: testCase.hasUsableStorageLocation,
            cloudContainer: testCase.cloudContainer,
            cloudDocuments: testCase.cloudDocuments,
            localDocuments: testCase.localDocuments,
            storageRoot: testCase.storageRoot,
            audioDisk: testCase.audioDisk,
            dbDirName: AudioPluginInfo.effectiveDBDirName
        )

        #expect(diagnostics.failureReason == testCase.expectedReason)
        #expect(diagnostics.summary.contains("failureReason = \(testCase.expectedReason)"))
    }
}

@Test
func audioStorageDiagnosticsHasNoFailureWhenRepositoryIsReady() {
    let diagnostics = AudioStorageDiagnostics(
        storageLocationRaw: "local",
        isICloudAvailable: false,
        hasUsableStorageLocation: true,
        cloudContainer: nil,
        cloudDocuments: nil,
        localDocuments: "/Users/test/Documents",
        storageRoot: "/Users/test/Documents/Cisum",
        audioDisk: "/Users/test/Documents/Cisum/\(AudioPluginInfo.effectiveDBDirName)",
        dbDirName: AudioPluginInfo.effectiveDBDirName
    )

    #expect(diagnostics.failureReason == nil)
    #expect(diagnostics.summary.contains("storageRoot = /Users/test/Documents/Cisum"))
    #expect(diagnostics.summary.contains("dbDirName = \(AudioPluginInfo.effectiveDBDirName)"))
}

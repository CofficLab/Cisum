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

/// 不跟踪扫描状态的实现方落到协议扩展的默认值：**不**认为仓库为空。
///
/// 「不知道」≠「是空的」——误报会让空仓库引导在有歌的仓库上照样弹出来。
@Test @MainActor
func audioLibraryWithoutScanTrackingIsNotAssumedEmpty() {
    let provider = StubAudioLibraryProvider()

    #expect(provider.isRepositoryEmpty == false)
}

@Test
func unavailableLibraryErrorIsTransportSafe() async {
    let task = Task.detached { () throws -> Void in
        throw AudioLibraryProvidingError.unavailable
    }
    do {
        try await task.value
        Issue.record("应保留跨任务传递的 unavailable 错误")
    } catch AudioLibraryProvidingError.unavailable {
        // 跨并发边界后仍可精确匹配领域错误。
    } catch {
        Issue.record("错误类型发生变化：\(error)")
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

@Test(arguments: ["local", "custom"])
func nonCloudStorageDoesNotRequireCloudAvailability(location: String) {
    let diagnostics = AudioStorageDiagnostics(
        storageLocationRaw: location, isICloudAvailable: false, hasUsableStorageLocation: true,
        cloudContainer: nil, cloudDocuments: nil, localDocuments: nil,
        storageRoot: "/音频", audioDisk: "/音频/audios", dbDirName: "audios"
    )
    #expect(diagnostics.failureReason == nil)
    #expect(!diagnostics.summary.contains("failureReason"))
    #expect(diagnostics.summary.split(separator: "\n").count == 9)
}

@Test
func diagnosticsSummaryIncludesEveryFieldAndNilPlaceholder() {
    let diagnostics = AudioStorageDiagnostics(
        storageLocationRaw: nil, isICloudAvailable: false, hasUsableStorageLocation: false,
        cloudContainer: nil, cloudDocuments: nil, localDocuments: "/本地 Documents",
        storageRoot: nil, audioDisk: nil, dbDirName: "audios_debug"
    )
    #expect(diagnostics.summary == """
    StorageLocation(raw) = nil
    hasUsableStorageLocation = false
    isICloudAvailable = false
    cloudContainer = nil
    cloudDocuments = nil
    localDocuments = /本地 Documents
    storageRoot = nil
    audioDisk = nil
    dbDirName = audios_debug
    failureReason = Storage location is not set. Go to Storage settings and choose iCloud or Local.
    """)
}

@Test(arguments: [
    (Optional<String>.none, Optional<String>.none, "Storage root could not be resolved for location 'icloud'."),
    (Optional("/cloud"), Optional<String>.none, "Audio repository directory could not be created at storage root."),
    (Optional("/cloud"), Optional("/cloud/audios"), Optional<String>.none),
])
func cloudDiagnosticsContinuePastResolvedContainer(root: String?, disk: String?, reason: String?) {
    let diagnostics = AudioStorageDiagnostics(
        storageLocationRaw: "icloud", isICloudAvailable: true, hasUsableStorageLocation: true,
        cloudContainer: "/container", cloudDocuments: "/cloud", localDocuments: nil,
        storageRoot: root, audioDisk: disk, dbDirName: "audios"
    )
    #expect(diagnostics.failureReason == reason)
    #expect(diagnostics.summary.contains("cloudContainer = /container"))
    #expect(diagnostics.summary.contains("cloudDocuments = /cloud"))
}

@Test
func deletionEventPreservesURLsAndCountAcrossTaskBoundary() async {
    let urls = [URL(fileURLWithPath: "/音频/a b.mp3"), URL(fileURLWithPath: "/音频/c.flac")]
    let event = AudioLibraryProvidingEvent.deleted(urls: urls, totalCount: 7)
    let received = await Task.detached { event }.value
    guard case .deleted(let receivedURLs, let totalCount) = received else {
        Issue.record("应收到 deleted 事件")
        return
    }
    #expect(receivedURLs == urls)
    #expect(totalCount == 7)
}

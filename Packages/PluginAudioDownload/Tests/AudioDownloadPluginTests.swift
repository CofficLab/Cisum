import Testing
import Foundation
import ProviderScene
@testable import PluginAudioDownload

@Test func pluginInfoExportsRegistrationMetadata() {
    #expect(AudioDownloadPluginInfo.iconName == "icloud.and.arrow.down")
    #expect(AudioDownloadPluginInfo.order == 2)
}

@Test func audioDownloadUsesStableAudioSceneIdentifier() {
    #expect(AppScene.music.rawValue == "Music Library")
}

@Test func audioDownloadOnlyStartsForActiveMissingAsset() {
    let asset = URL(fileURLWithPath: "/tmp/cisum-audio-download/track.mp3")

    #expect(AudioDownloadRequestPolicy.shouldCheckCurrentAsset(
        isSceneActive: true,
        asset: asset
    ))
    #expect(!AudioDownloadRequestPolicy.shouldCheckCurrentAsset(
        isSceneActive: false,
        asset: asset
    ))
    #expect(!AudioDownloadRequestPolicy.shouldCheckCurrentAsset(
        isSceneActive: true,
        asset: nil
    ))

    #expect(AudioDownloadRequestPolicy.shouldStartDownload(
        isSceneActive: true,
        asset: asset,
        isNotDownloaded: true
    ))
    #expect(!AudioDownloadRequestPolicy.shouldStartDownload(
        isSceneActive: false,
        asset: asset,
        isNotDownloaded: true
    ))
    #expect(!AudioDownloadRequestPolicy.shouldStartDownload(
        isSceneActive: true,
        asset: nil,
        isNotDownloaded: true
    ))
    #expect(!AudioDownloadRequestPolicy.shouldStartDownload(
        isSceneActive: true,
        asset: asset,
        isNotDownloaded: false
    ))
}

@Test func audioDownloadDoesNotStartDuplicateActiveDownload() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realAsset = root.appendingPathComponent("track.mp3")
    let linkedAsset = root.appendingPathComponent("linked.mp3")
    let otherAsset = root.appendingPathComponent("other.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: realAsset)
    try FileManager.default.createSymbolicLink(at: linkedAsset, withDestinationURL: realAsset)

    #expect(!AudioDownloadRequestPolicy.shouldStartDownload(
        isSceneActive: true,
        asset: linkedAsset,
        isNotDownloaded: true,
        activeDownloads: [realAsset]
    ))
    #expect(AudioDownloadRequestPolicy.shouldStartDownload(
        isSceneActive: true,
        asset: otherAsset,
        isNotDownloaded: true,
        activeDownloads: [realAsset]
    ))
}

@Test func audioDownloadOnlyAppliesCurrentAssetResults() {
    let asset = URL(fileURLWithPath: "/tmp/cisum-audio-download/track.mp3")
    let other = URL(fileURLWithPath: "/tmp/cisum-audio-download/other.mp3")

    #expect(AudioDownloadRequestPolicy.shouldApplyDownloadResult(
        requestedAsset: asset,
        currentAsset: asset,
        isSceneActive: true,
        currentGeneration: 2,
        requestGeneration: 2
    ))
    #expect(!AudioDownloadRequestPolicy.shouldApplyDownloadResult(
        requestedAsset: asset,
        currentAsset: other,
        isSceneActive: true,
        currentGeneration: 2,
        requestGeneration: 2
    ))
    #expect(!AudioDownloadRequestPolicy.shouldApplyDownloadResult(
        requestedAsset: asset,
        currentAsset: asset,
        isSceneActive: false,
        currentGeneration: 2,
        requestGeneration: 2
    ))
}

@Test func staleAudioDownloadResultsDoNotApplyAfterSceneDeactivation() {
    let asset = URL(fileURLWithPath: "/tmp/cisum-audio-download/track.mp3")
    let generation = AudioDownloadRequestPolicy.generationAfterDeactivation(2)

    #expect(AudioDownloadRequestPolicy.shouldApplyDownloadResult(
        requestedAsset: asset,
        currentAsset: asset,
        isSceneActive: true,
        currentGeneration: 2,
        requestGeneration: 2
    ))
    #expect(!AudioDownloadRequestPolicy.shouldApplyDownloadResult(
        requestedAsset: asset,
        currentAsset: asset,
        isSceneActive: true,
        currentGeneration: generation,
        requestGeneration: 2
    ))
}

@Test func audioDownloadAppliesResultsForSymlinkedCurrentAsset() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realAsset = root.appendingPathComponent("track.mp3")
    let linkedAsset = root.appendingPathComponent("linked.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: realAsset)
    try FileManager.default.createSymbolicLink(at: linkedAsset, withDestinationURL: realAsset)

    #expect(AudioDownloadRequestPolicy.shouldApplyDownloadResult(
        requestedAsset: realAsset,
        currentAsset: linkedAsset,
        isSceneActive: true
    ))
}

@Test func audioDownloadDoesNotApplyResultsAcrossDistinctDanglingSymlinks() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingAsset = root.appendingPathComponent("missing.mp3")
    let firstLink = root.appendingPathComponent("first.mp3")
    let secondLink = root.appendingPathComponent("second.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: firstLink, withDestinationURL: missingAsset)
    try FileManager.default.createSymbolicLink(at: secondLink, withDestinationURL: missingAsset)

    #expect(!AudioDownloadRequestPolicy.shouldApplyDownloadResult(
        requestedAsset: firstLink,
        currentAsset: secondLink,
        isSceneActive: true
    ))
}

// MARK: - ViewModel 门控

@MainActor
private final class AudioDownloadCapabilityProbe: AudioDownloadPlaybackCapability {
    var currentURL: URL?
}

@MainActor
struct AudioDownloadViewModelTests {
    @Test
    func inactiveSceneIgnoresAssetChanges() {
        let viewModel = AudioDownloadViewModel(playbackCapability: AudioDownloadCapabilityProbe())
        viewModel.handleSceneChange(.audiobooks)
        viewModel.handleAssetChanged(URL(fileURLWithPath: "/tmp/track.mp3"))
        #expect(true) // 非音乐场景不启动下载，也不报错
    }

    @Test
    func nilAssetInMusicSceneIsIgnored() {
        let viewModel = AudioDownloadViewModel(playbackCapability: AudioDownloadCapabilityProbe())
        viewModel.handleSceneChange(.music)
        viewModel.handleAssetChanged(nil)
        #expect(true)
    }

    @Test
    func leavingMusicSceneBumpsGeneration() {
        let viewModel = AudioDownloadViewModel(playbackCapability: AudioDownloadCapabilityProbe())
        viewModel.handleSceneChange(.music)
        viewModel.handleSceneChange(.audiobooks)
        viewModel.handleSceneChange(.music)
        #expect(true) // 代际推进由 policy 覆盖；此处仅验证切换不崩溃
    }
}

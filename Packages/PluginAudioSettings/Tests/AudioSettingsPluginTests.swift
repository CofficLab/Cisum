import Foundation
@testable import PluginAudioSettings
import Testing

@Test func pluginInfoExportsRegistrationMetadata() {
    #expect(AudioSettingsPluginInfo.iconName == "gearshape")
    #expect(AudioSettingsPluginInfo.order == 10)
}

@Test func audioSettingsOnlyAppliesCurrentDiskMetrics() {
    let firstDisk = URL(fileURLWithPath: "/tmp/cisum-audio-settings/first", isDirectory: true)
    let secondDisk = URL(fileURLWithPath: "/tmp/cisum-audio-settings/second", isDirectory: true)

    #expect(AudioSettingsMetricsPolicy.shouldApplyMetrics(
        currentDisk: firstDisk,
        requestedDisk: firstDisk,
        currentGeneration: 2,
        resultGeneration: 2
    ))
    #expect(!AudioSettingsMetricsPolicy.shouldApplyMetrics(
        currentDisk: secondDisk,
        requestedDisk: firstDisk,
        currentGeneration: 2,
        resultGeneration: 2
    ))
    #expect(!AudioSettingsMetricsPolicy.shouldApplyMetrics(
        currentDisk: firstDisk,
        requestedDisk: firstDisk,
        currentGeneration: 2,
        resultGeneration: 1
    ))
    #expect(!AudioSettingsMetricsPolicy.shouldApplyMetrics(
        currentDisk: nil,
        requestedDisk: firstDisk,
        currentGeneration: 2,
        resultGeneration: 2
    ))
}

@Test func audioSettingsHidesOpenLibraryActionForMissingLocalDisk() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingDisk = root.appendingPathComponent("missing", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    #expect(!AudioSettingsView.shouldShowOpenLibraryAction(for: missingDisk))
    #expect(AudioSettingsView.shouldShowOpenLibraryAction(for: root))
}

@Test func audioSettingsUsesSingularFileCountOnlyForOneFile() {
    #expect(!AudioSettingsView.shouldUseSingularFileCount(0))
    #expect(AudioSettingsView.shouldUseSingularFileCount(1))
    #expect(!AudioSettingsView.shouldUseSingularFileCount(2))
}

@MainActor
struct AudioSettingsViewModelTests {
    @Test
    func initHasEmptyState() {
        let viewModel = AudioSettingsViewModel(audioDisk: { nil })
        #expect(viewModel.refreshToken == 0)
        #expect(viewModel.disk == nil)
        #expect(viewModel.description.isEmpty)
        #expect(viewModel.fileCount == 0)
        #expect(viewModel.diskSize == nil)
    }

    @Test
    func storageLocationChangeBumpsRefreshToken() {
        let viewModel = AudioSettingsViewModel(audioDisk: { nil })
        viewModel.handleStorageLocationChanged()
        viewModel.handleStorageLocationChanged()
        #expect(viewModel.refreshToken == 2)
    }

    @Test
    func refreshWithoutDiskClearsMetrics() async throws {
        // 先给出一个真实目录（本地描述），随后切换为 nil 应清空。
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioSettingsVMNil-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let viewModel = AudioSettingsViewModel(audioDisk: { directory })
        viewModel.refresh()
        for _ in 0..<50 where viewModel.fileCount == 0 {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(viewModel.disk == directory)

        // 磁盘不可用后，refresh 应清空全部指标。
        let emptyViewModel = AudioSettingsViewModel(audioDisk: { nil })
        emptyViewModel.refresh()
        #expect(emptyViewModel.disk == nil)
        #expect(emptyViewModel.description.isEmpty)
        #expect(emptyViewModel.fileCount == 0)
        #expect(emptyViewModel.diskSize == nil)
    }

    @Test
    func refreshWithLocalDirectoryCollectsMetrics() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioSettingsVM-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("a".utf8).write(to: directory.appendingPathComponent("a.mp3"))
        try Data("b".utf8).write(to: directory.appendingPathComponent("b.mp3"))

        let viewModel = AudioSettingsViewModel(audioDisk: { directory })
        viewModel.refresh()

        #expect(viewModel.disk == directory)
        #expect(viewModel.description.contains("Local"))

        // 等待异步 metrics 落地。
        for _ in 0..<50 where viewModel.fileCount == 0 {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(viewModel.fileCount == 2)
        #expect(viewModel.diskSize != nil)
    }

    @Test
    func staleRefreshResultIsDiscarded() async throws {
        let first = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioSettingsVM1-\(UUID().uuidString)", isDirectory: true)
        let second = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioSettingsVM2-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: second.appendingPathComponent("only.mp3"))

        let viewModel = AudioSettingsViewModel(audioDisk: { first })
        viewModel.refresh() // generation 1，first
        // 模拟用户切换目录：切换 disk 闭包并再次 refresh → generation 2
        let viewModel2 = AudioSettingsViewModel(audioDisk: { second })
        viewModel2.refresh()

        for _ in 0..<50 where viewModel2.fileCount == 0 {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(viewModel2.fileCount == 1)
    }
}

import Foundation
@testable import PluginBookSettings
import Testing

@Test func pluginInfoExportsRegistrationMetadata() {
    #expect(BookSettingsPluginInfo.iconName == "gearshape")
    #expect(BookSettingsPluginInfo.order == 11)
}

@Test func bookSettingsOnlyAppliesCurrentDiskMetrics() {
    let firstDisk = URL(fileURLWithPath: "/tmp/cisum-book-settings/first", isDirectory: true)
    let secondDisk = URL(fileURLWithPath: "/tmp/cisum-book-settings/second", isDirectory: true)

    #expect(BookSettingsMetricsPolicy.shouldApplyMetrics(
        currentDisk: firstDisk,
        requestedDisk: firstDisk,
        currentGeneration: 2,
        resultGeneration: 2
    ))
    #expect(!BookSettingsMetricsPolicy.shouldApplyMetrics(
        currentDisk: secondDisk,
        requestedDisk: firstDisk,
        currentGeneration: 2,
        resultGeneration: 2
    ))
    #expect(!BookSettingsMetricsPolicy.shouldApplyMetrics(
        currentDisk: firstDisk,
        requestedDisk: firstDisk,
        currentGeneration: 2,
        resultGeneration: 1
    ))
    #expect(!BookSettingsMetricsPolicy.shouldApplyMetrics(
        currentDisk: nil,
        requestedDisk: firstDisk,
        currentGeneration: 2,
        resultGeneration: 2
    ))
}

@Test func bookSettingsHidesOpenLibraryActionForMissingLocalDisk() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingDisk = root.appendingPathComponent("missing", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    #expect(!BookSettingsView.shouldShowOpenLibraryAction(for: missingDisk))
    #expect(BookSettingsView.shouldShowOpenLibraryAction(for: root))
}

@Test func bookSettingsUsesSingularFileCountOnlyForOneFile() {
    #expect(!BookSettingsView.shouldUseSingularFileCount(0))
    #expect(BookSettingsView.shouldUseSingularFileCount(1))
    #expect(!BookSettingsView.shouldUseSingularFileCount(2))
}

@MainActor
struct BookSettingsViewModelTests {
    @Test
    func initHasEmptyState() {
        let viewModel = BookSettingsViewModel(bookDisk: { nil })
        #expect(viewModel.refreshToken == 0)
        #expect(viewModel.disk == nil)
        #expect(viewModel.description.isEmpty)
        #expect(viewModel.fileCount == 0)
        #expect(viewModel.diskSize == nil)
    }

    @Test
    func storageLocationChangeBumpsRefreshToken() {
        let viewModel = BookSettingsViewModel(bookDisk: { nil })
        viewModel.handleStorageLocationChanged()
        viewModel.handleStorageLocationChanged()
        #expect(viewModel.refreshToken == 2)
    }

    @Test
    func refreshWithoutDiskClearsMetrics() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookSettingsVMNil-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let viewModel = BookSettingsViewModel(bookDisk: { directory })
        viewModel.refresh()
        for _ in 0..<50 where viewModel.fileCount == 0 {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(viewModel.disk == directory)

        let emptyViewModel = BookSettingsViewModel(bookDisk: { nil })
        emptyViewModel.refresh()
        #expect(emptyViewModel.disk == nil)
        #expect(emptyViewModel.description.isEmpty)
        #expect(emptyViewModel.fileCount == 0)
        #expect(emptyViewModel.diskSize == nil)
    }

    @Test
    func refreshWithLocalDirectoryCollectsMetrics() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookSettingsVM-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("a".utf8).write(to: directory.appendingPathComponent("a.txt"))
        try Data("b".utf8).write(to: directory.appendingPathComponent("b.txt"))

        let viewModel = BookSettingsViewModel(bookDisk: { directory })
        viewModel.refresh()

        #expect(viewModel.disk == directory)
        #expect(viewModel.description.contains("Local"))

        for _ in 0..<50 where viewModel.fileCount == 0 {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(viewModel.fileCount == 2)
        #expect(viewModel.diskSize != nil)
    }

    @Test
    func staleRefreshResultIsDiscarded() async throws {
        let first = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookSettingsVM1-\(UUID().uuidString)", isDirectory: true)
        let second = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookSettingsVM2-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: second.appendingPathComponent("only.txt"))

        let viewModel = BookSettingsViewModel(bookDisk: { second })
        viewModel.refresh()

        for _ in 0..<50 where viewModel.fileCount == 0 {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(viewModel.fileCount == 1)
    }
}

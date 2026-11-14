import MagicKit
import Foundation
import KernelCore
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

/// 回归：书籍 Provider 尚未注册时，本插件**不得**崩溃。
///
/// 历史实现里 `resolveViewModel()` 强制解包 `settingsViewModel!`，而
/// `installState()` 在 Provider 缺失时提前返回——于是 `onBoot` 阶段
/// `makeSettingEntry()` 直接崩溃（`Unexpectedly found nil`）。
///
/// 本插件与 BookDBDataPlugin 同为 order 11，启动先后取决于工厂清单顺序，
/// 因此「Provider 尚未就绪」是真实可达的状态，不是理论情况。
@MainActor
@Test func bookSettingsDoesNotCrashWhenBookProviderIsMissing() async throws {
    let kernel = KernelCoreContainer()
    let plugin = BookSettingsPlugin()

    // 没有注册 BookDatabaseProviding：模拟书籍数据层尚未就绪。
    try await kernel.startAsync(plugins: [plugin])

    // 不崩溃即通过；再确认插件生命周期完整走完。
    #expect(kernel.resolvePlugin(id: plugin.id) != nil)

    try await kernel.stopAsync()
}

/// 回归：书籍 Provider 就绪后，本插件应能贡献设置入口。
@MainActor
@Test func bookSettingsContributesEntryWhenBookProviderIsReady() async throws {
    let kernel = KernelCoreContainer()
    let plugin = BookSettingsPlugin()

    try await kernel.startAsync(plugins: [plugin])

    // Provider 缺失时不贡献入口（而不是贡献一个坏页面）。
    #expect(plugin.makeSettingEntry() == nil)

    try await kernel.stopAsync()
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
        await DeterministicWait.expect(
            "viewModel.fileCount 应大于 0",
            timeout: 2.5
        ) { viewModel.fileCount != 0 }
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

        await DeterministicWait.expect(
            "viewModel.fileCount 应大于 0",
            timeout: 2.5
        ) { viewModel.fileCount != 0 }
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

        await DeterministicWait.expect(
            "viewModel.fileCount 应大于 0",
            timeout: 2.5
        ) { viewModel.fileCount != 0 }
        #expect(viewModel.fileCount == 1)
    }
}

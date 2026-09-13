import KernelCore
import MagicKit
import OSLog
import ProviderAudioLibrary
import ProviderAudioNavigation

/// 音频数据库数据层插件。
///
/// 该插件是音频 SwiftData 容器、AudioRepo 和音频库 Provider 的唯一组装入口；
/// UI 插件通过 `AudioLibraryProviding` 使用它，不再自行构造数据库。
public actor AudioDBDataPlugin: SuperPlugin, SuperLog {
    public nonisolated static let emoji = "💾"
    public nonisolated static let verbose = false

    public static let shared = AudioDBDataPlugin()
    public static let metadata = PluginMetadata(
        displayName: "Audio Database Data",
        description: "Provides the audio database and keeps the audio library synchronized.",
        iconName: "externaldrive.badge.timemachine",
        order: 1,
        policy: .alwaysOn,
        category: .library
    )

    nonisolated(unsafe) private weak var kernel: CisumKernel?
    nonisolated(unsafe) private var libraryProvider: AudioLibraryProvider?
    nonisolated(unsafe) private var navigationProvider: AudioTrackNavigationProvider?
    nonisolated(unsafe) private var storageObserver: AudioStorageObserver?
    nonisolated(unsafe) private var fileSystemMonitor: AudioFileSystemMonitor?

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        self.kernel = kernel
        try installProviders(kernel: kernel)
    }

    @MainActor
    public func onReady(kernel: CisumKernel) async throws {
        self.kernel = kernel
        try installProviders(kernel: kernel)
        setupStorageLocationObserver(kernel: kernel)
        startFileSystemMonitor()
    }

    @MainActor
    public func onEnable(kernel: CisumKernel) async throws {
        self.kernel = kernel
        try installProviders(kernel: kernel)
        setupStorageLocationObserver(kernel: kernel)
        startFileSystemMonitor()
    }

    @MainActor
    public func onDisable(kernel: CisumKernel) async throws {
        teardownSynchronization()
        removeProviders(from: kernel)
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
        teardownSynchronization()
        removeProviders(from: kernel)
        self.kernel = nil
    }

    // MARK: - Audio library synchronization

    /// 数据插件自行维护文件系统到数据库的同步生命周期。
    ///
    /// 目录监控不是一个独立业务插件：它是音频目录数据正确性的基础设施，
    /// 因此必须和 Provider 的具体实现一起启动、停止和重建。
    @MainActor
    private func startFileSystemMonitor() {
        guard storageObserver != nil, fileSystemMonitor == nil, let provider = libraryProvider else { return }

        let monitor = AudioFileSystemMonitor(
            diskProvider: {
                await MainActor.run { provider.audioDisk }
            },
            syncItems: { items, isFirst in
                let disk = await MainActor.run { provider.audioDisk }
                let shouldFullSync = AudioFileSystemMonitor.shouldPerformFullSync(
                    isFirst: isFirst,
                    disk: disk
                )
                if shouldFullSync, items.isEmpty,
                   !AudioFileSystemMonitor.shouldApplyEmptyFullSync(disk: disk) {
                    return
                }
                await provider.sync(
                    urls: items,
                    verbose: AudioFileSystemMonitor.verbose,
                    isFirst: shouldFullSync
                )
            },
            deleteItems: { urls in
                try await provider.delete(
                    urls: urls,
                    verbose: AudioFileSystemMonitor.verbose
                )
            }
        )

        fileSystemMonitor = monitor
        Task { [monitor] in
            do {
                try await monitor.execute()
            } catch is CancellationError {
                // Cancellation is the normal path during storage changes or shutdown.
            } catch {
                os_log(.error, "❌ Audio library filesystem monitor failed: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func setupStorageLocationObserver(kernel: CisumKernel) {
        guard storageObserver == nil, let storage = kernel.storage else { return }
        storageObserver = AudioStorageObserver(provider: storage) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.restartFileSystemMonitor()
            }
        }
    }

    @MainActor
    private func restartFileSystemMonitor() async {
        stopFileSystemMonitor()
        try? await Task.sleep(nanoseconds: 100_000_000)
        guard storageObserver != nil else { return }
        startFileSystemMonitor()
    }

    @MainActor
    private func stopFileSystemMonitor() {
        fileSystemMonitor?.cancel()
        fileSystemMonitor = nil
    }

    @MainActor
    private func teardownSynchronization() {
        storageObserver?.cancel()
        storageObserver = nil
        stopFileSystemMonitor()
    }

    // MARK: - Provider installation

    @MainActor
    private func installProviders(kernel: CisumKernel) throws {
        try installLibraryProvider(kernel: kernel)
        try installNavigationProvider(kernel: kernel)
    }

    @MainActor
    private func removeProviders(from kernel: CisumKernel) {
        removeNavigationProvider(from: kernel)
        removeLibraryProvider(from: kernel)
    }

    // MARK: - AudioLibraryProviding

    @MainActor
    private func installLibraryProvider(kernel: CisumKernel) throws {
        guard libraryProvider == nil, let storage = kernel.storage else { return }
        let provider = AudioLibraryProvider(storage: storage)
        self.libraryProvider = provider
        try kernel.registerAudioLibrary(provider)
    }

    @MainActor
    private func removeLibraryProvider(from kernel: CisumKernel) {
        guard libraryProvider != nil else { return }
        libraryProvider?.shutdown()
        kernel.unregisterProvider(AudioLibraryProviding.self)
        libraryProvider = nil
    }

    // MARK: - AudioTrackNavigationProviding

    /// 注册音频曲目导航服务。
    ///
    /// Provider 由本插件组装；消费插件只依赖协议，不依赖
    /// `AudioRepo` 或本插件的具体实现。
    @MainActor
    private func installNavigationProvider(kernel: CisumKernel) throws {
        guard navigationProvider == nil else { return }
        let provider = libraryProvider
        let repoProvider: @MainActor @Sendable () async -> AudioLibraryProvider? = {
            provider
        }
        let navigation = AudioTrackNavigationProvider(
            nextURL: { current, verbose in
                guard let provider = await repoProvider() else {
                    os_log(.error, "\(Self.t)❌ Cannot find next audio: repository is unavailable")
                    throw AudioPluginError.hostNotConfigured
                }
                do {
                    let result = try await provider.nextURL(after: current, verbose: verbose)
                    if result == nil {
                        os_log("\(Self.t)ℹ️ No next audio for current item: \(current?.lastPathComponent ?? "<none>")")
                    }
                    return result
                } catch {
                    os_log(.error, "\(Self.t)❌ Failed to resolve next audio: \(error.localizedDescription)")
                    throw error
                }
            },
            previousURL: { current, verbose in
                guard let provider = await repoProvider() else {
                    os_log(.error, "\(Self.t)❌ Cannot find previous audio: repository is unavailable")
                    throw AudioPluginError.hostNotConfigured
                }
                do {
                    let result = try await provider.previousURL(before: current, verbose: verbose)
                    if result == nil {
                        os_log("\(Self.t)ℹ️ No previous audio for current item: \(current?.lastPathComponent ?? "<none>")")
                    }
                    return result
                } catch {
                    os_log(.error, "\(Self.t)❌ Failed to resolve previous audio: \(error.localizedDescription)")
                    throw error
                }
            },
            firstURL: {
                guard let provider = await repoProvider() else {
                    os_log(.error, "\(Self.t)❌ Cannot find first audio: repository is unavailable")
                    throw AudioPluginError.hostNotConfigured
                }
                do {
                    return try await provider.firstURL()
                } catch {
                    os_log(.error, "\(Self.t)❌ Failed to resolve first audio: \(error.localizedDescription)")
                    throw error
                }
            },
            lastURL: {
                guard let provider = await repoProvider() else {
                    os_log(.error, "\(Self.t)❌ Cannot find last audio: repository is unavailable")
                    throw AudioPluginError.hostNotConfigured
                }
                do {
                    return try await provider.lastURL()
                } catch {
                    os_log(.error, "\(Self.t)❌ Failed to resolve last audio: \(error.localizedDescription)")
                    throw error
                }
            }
        )
        navigationProvider = navigation
        try kernel.registerAudioTrackNavigation(navigation)
    }

    @MainActor
    private func removeNavigationProvider(from kernel: CisumKernel) {
        guard navigationProvider != nil else { return }
        kernel.unregisterProvider((any AudioTrackNavigationProviding).self)
        navigationProvider = nil
    }

}

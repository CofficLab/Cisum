import KernelCore
import MagicKit
import OSLog
import ProviderAudioLibrary
import ProviderAudioNavigation
import ProviderStorage

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
        description: "Provides the audio database and repository service.",
        iconName: "externaldrive.badge.timemachine",
        order: 1,
        policy: .alwaysOn,
        category: .library
    )

    nonisolated(unsafe) private weak var kernel: CisumKernel?
    nonisolated(unsafe) private var libraryProvider: AudioLibraryProvider?
    nonisolated(unsafe) private var navigationProvider: AudioTrackNavigationProvider?

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        self.kernel = kernel
        installProviders(kernel: kernel)
    }

    @MainActor
    public func onReady(kernel: CisumKernel) async throws {
        installProviders(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: CisumKernel) async throws {
        self.kernel = kernel
        installProviders(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: CisumKernel) async throws {
        removeProviders(from: kernel)
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
        removeProviders(from: kernel)
        self.kernel = nil
    }

    // MARK: - Provider installation

    @MainActor
    private func installProviders(kernel: CisumKernel) {
        installLibraryProvider(kernel: kernel)
        installNavigationProvider(kernel: kernel)
    }

    @MainActor
    private func removeProviders(from kernel: CisumKernel) {
        removeNavigationProvider(from: kernel)
        removeLibraryProvider(from: kernel)
    }

    // MARK: - AudioLibraryProviding

    @MainActor
    private func installLibraryProvider(kernel: CisumKernel) {
        guard libraryProvider == nil, let storage = kernel.storage else { return }
        let provider = AudioLibraryProvider(storage: storage)
        self.libraryProvider = provider
        kernel.registerAudioLibrary(provider)
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
    private func installNavigationProvider(kernel: CisumKernel) {
        guard navigationProvider == nil else { return }
        let repoProvider: @MainActor @Sendable () async -> AudioRepo? = { [weak self] in
            await self?.currentRepo()
        }
        let provider = AudioTrackNavigationProvider(
            nextURL: { current, verbose in
                guard let repo = await repoProvider() else {
                    os_log(.error, "\(Self.t)❌ Cannot find next audio: repository is unavailable")
                    throw AudioPluginError.hostNotConfigured
                }
                do {
                    let result = try await repo.getNextOf(current, verbose: verbose)
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
                guard let repo = await repoProvider() else {
                    os_log(.error, "\(Self.t)❌ Cannot find previous audio: repository is unavailable")
                    throw AudioPluginError.hostNotConfigured
                }
                do {
                    let result = try await repo.getPrevOf(current, verbose: verbose)
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
                guard let repo = await repoProvider() else {
                    os_log(.error, "\(Self.t)❌ Cannot find first audio: repository is unavailable")
                    throw AudioPluginError.hostNotConfigured
                }
                do {
                    return try await repo.getFirst()
                } catch {
                    os_log(.error, "\(Self.t)❌ Failed to resolve first audio: \(error.localizedDescription)")
                    throw error
                }
            },
            lastURL: {
                guard let repo = await repoProvider() else {
                    os_log(.error, "\(Self.t)❌ Cannot find last audio: repository is unavailable")
                    throw AudioPluginError.hostNotConfigured
                }
                do {
                    return try await repo.getLast()
                } catch {
                    os_log(.error, "\(Self.t)❌ Failed to resolve last audio: \(error.localizedDescription)")
                    throw error
                }
            }
        )
        navigationProvider = provider
        kernel.registerAudioTrackNavigation(provider)
    }

    @MainActor
    private func removeNavigationProvider(from kernel: CisumKernel) {
        guard navigationProvider != nil else { return }
        kernel.unregisterProvider((any AudioTrackNavigationProviding).self)
        navigationProvider = nil
    }

    // MARK: - Repo access

    @MainActor
    private func currentRepo() async -> AudioRepo? {
        await libraryProvider?.audioRepo
    }
}

import CisumUIComponents
import KernelCore
import ProviderDocsView
import Foundation
import OSLog
import ProviderAudioLibrary
import ProviderStorage
import MagicKit

public actor AudioJobPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = true

    public static let shared = AudioJobPlugin()
    public static let metadata = PluginMetadata(
        displayName: String(localized: "Audio Jobs", bundle: .module),
        description: String(localized: "Background tasks for audio files", bundle: .module),
        iconName: "gearshape.2",
        order: 5,
        category: .system,
    )

    nonisolated(unsafe) private var storageObserver: AudioJobStorageObserver?
    nonisolated(unsafe) private weak var kernel: CisumKernel?

    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioJobPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioJobPluginManualView() })
        }
    }

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        self.kernel = kernel
        await registerJobs()
        setupStorageLocationObserver()
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
        storageObserver?.cancel()
        storageObserver = nil
        self.kernel = nil
    }

    private func registerJobs() async {
        let manager = AudioJobManager.shared
        let fsMonitorJob = makeFileSystemMonitorJob()

        await manager.register(fsMonitorJob)
        await manager.startJob(fsMonitorJob.identifier)
    }

    @MainActor
    private func setupStorageLocationObserver() {
        guard storageObserver == nil else { return }
        guard let storage = kernel?.storage else { return }
        storageObserver = AudioJobStorageObserver(provider: storage) { [weak self] in
            Task {
                await self?.restartFileSystemMonitor()
            }
        }
    }

    private func restartFileSystemMonitor() async {
        let manager = AudioJobManager.shared
        let identifier = FileSystemMonitorJob(
            diskProvider: { nil },
            syncItems: { _, _ in },
            deleteItems: { _ in }
        ).identifier

        await manager.stopJob(identifier)
        try? await Task.sleep(nanoseconds: 100_000_000)
        await manager.startJob(identifier)
    }

    private func makeFileSystemMonitorJob() -> FileSystemMonitorJob {
        FileSystemMonitorJob(
            diskProvider: {
                await MainActor.run { self.kernel?.audioLibrary?.audioDisk }
            },
            syncItems: { items, isFirst in
                guard let library = await MainActor.run(body: { self.kernel?.audioLibrary }) else {
                    return
                }

                let disk = await MainActor.run { library.audioDisk }
                let shouldFullSync = FileSystemMonitorJob.shouldPerformFullSync(isFirst: isFirst, disk: disk)
                await library.sync(
                    urls: items,
                    verbose: FileSystemMonitorJob.verbose,
                    isFirst: shouldFullSync
                )
            },
            deleteItems: { urls in
                guard let library = await MainActor.run(body: { self.kernel?.audioLibrary }) else {
                    return
                }

                try await library.delete(urls: urls, verbose: FileSystemMonitorJob.verbose)
            },
            notifyDeletion: {}
        )
    }
}

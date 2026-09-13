import ProviderStorage
import Foundation
import ProviderStorage
import Testing
@testable import PluginAudio

@Test func missingStorageErrorKeepsStorageSetupGuidance() {
    let presentation = AudioRootErrorPresentation.make(error: .storageMissing)

    #expect(presentation.title == "Storage Location Not Set")
    #expect(presentation.message == "Set the media library storage location first.")
    #expect(presentation.detail == nil)
}

@Test func databaseInitializationErrorShowsActualFailure() {
    let presentation = AudioRootErrorPresentation.make(error: .initialization("database is locked"))

    #expect(presentation.title == "Audio Library Initialization Failed")
    #expect(presentation.message == "Try reopening the app or checking media library settings.")
    #expect(presentation.detail == "database is locked")
}


@MainActor
struct AudioRootViewModelTests {
    @Test
    func reloadWithStorageFinishesInitialization() {
        let viewModel = AudioRootViewModel(hasStorageLocation: { true })
        viewModel.reloadContainer()
        #expect(viewModel.isInitializing == false)
        #expect(viewModel.error == nil)
    }

    @Test
    func reloadWithoutStorageReportsMissingStorage() {
        let viewModel = AudioRootViewModel(hasStorageLocation: { false })
        viewModel.reloadContainer()
        #expect(viewModel.isInitializing == false)
        #expect(viewModel.error == .storageMissing)
    }

    @Test
    func storageLocationChangeProducesNewNotice() {
        let viewModel = AudioRootViewModel(hasStorageLocation: { true })
        viewModel.handleStorageLocationChanged()
        let first = viewModel.storageLocationDidChangeNotice
        viewModel.handleStorageLocationChanged()
        #expect(viewModel.storageLocationDidChangeNotice != nil)
        #expect(viewModel.storageLocationDidChangeNotice != first)
    }
}

@MainActor
private final class StorageProviderProbe: StorageProviding {
    var currentStorageLocation: StorageLocation?
    var storageRoot: URL? { nil }
    var hasUsableStorageLocation = false
    var isICloudStorageAvailable = false
    var databaseRoot: URL { URL(fileURLWithPath: "/tmp/db", isDirectory: true) }
    private var observers: [(StorageProvidingEvent) -> Void] = []

    func storageRoot(for location: StorageLocation) -> URL? { nil }
    func databaseFile(name: String) throws -> URL { URL(fileURLWithPath: "/tmp/\(name).db") }
    func pluginDataDirectory(for pluginID: String) -> URL { URL(fileURLWithPath: "/tmp/\(pluginID)", isDirectory: true) }
    func setStorageLocation(_ location: StorageLocation?) {}
    func resetStorageLocation() {}
    func addObserver(_ callback: @escaping (StorageProvidingEvent) -> Void) -> any StorageProvidingObserverHandle {
        observers.append(callback)
        return StorageObserverProbeHandle { [weak self] in
            self?.observers = []
        }
    }
    func notify(_ event: StorageProvidingEvent) {
        observers.forEach { $0(event) }
    }
}

@MainActor
private final class StorageObserverProbeHandle: StorageProvidingObserverHandle {
    private let onCancel: () -> Void
    init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    func cancel() { onCancel() }
}

@MainActor
struct AudioStorageObserverTests {
    @Test
    func observerDrivesReloadOnStorageEvents() {
        let provider = StorageProviderProbe()
        provider.hasUsableStorageLocation = true
        let viewModel = AudioRootViewModel(hasStorageLocation: { provider.hasUsableStorageLocation })
        let observer = AudioStorageObserver(provider: provider, viewModel: viewModel)

        // 初始同步应完成一次加载。
        #expect(viewModel.isInitializing == false)

        provider.hasUsableStorageLocation = false
        provider.notify(.storageAvailabilityChanged)
        #expect(viewModel.error == .storageMissing)
        #expect(viewModel.storageLocationDidChangeNotice != nil)

        observer.cancel()
    }

    @Test
    func observerCancellationIsIdempotent() {
        let provider = StorageProviderProbe()
        let viewModel = AudioRootViewModel(hasStorageLocation: { true })
        let observer = AudioStorageObserver(provider: provider, viewModel: viewModel)
        observer.cancel()
        observer.cancel()
        #expect(true)
    }
}

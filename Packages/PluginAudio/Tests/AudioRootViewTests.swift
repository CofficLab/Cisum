import CisumProviderStorage
import Foundation
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


/// 最小存储能力探针：只提供可用性布尔量（适配器对 Provider 为 `weak`，
/// 无法包装临时 Provider，故字面量场景直接实现能力）。
@MainActor
private final class AudioStorageCapabilityProbe: AudioRootStorageCapability {
    var hasUsableStorageLocation: Bool

    init(hasUsable: Bool) {
        self.hasUsableStorageLocation = hasUsable
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioRootStorageEvent) -> Void
    ) -> any AudioRootStorageObserverHandle {
        NoopAudioStorageHandle()
    }
}

@MainActor
private final class NoopAudioStorageHandle: AudioRootStorageObserverHandle {
    func cancel() {}
}

@MainActor
private func makeStorage(hasUsable: Bool) -> AudioStorageCapabilityProbe {
    AudioStorageCapabilityProbe(hasUsable: hasUsable)
}

@MainActor
struct AudioRootViewModelTests {
    @Test
    func reloadWithStorageFinishesInitialization() {
        let viewModel = AudioRootViewModel(storage: makeStorage(hasUsable: true))
        viewModel.reloadContainer()
        #expect(viewModel.isInitializing == false)
        #expect(viewModel.error == nil)
    }

    @Test
    func reloadWithoutStorageReportsMissingStorage() {
        let viewModel = AudioRootViewModel(storage: makeStorage(hasUsable: false))
        viewModel.reloadContainer()
        #expect(viewModel.isInitializing == false)
        #expect(viewModel.error == .storageMissing)
    }

    @Test
    func storageLocationChangeProducesNewNotice() {
        let viewModel = AudioRootViewModel(storage: makeStorage(hasUsable: true))
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
        let storage = AudioRootStorageCapabilityAdapter(storage: provider)
        let viewModel = AudioRootViewModel(storage: storage)
        let observer = AudioStorageObserver(storage: storage, viewModel: viewModel)

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
        let viewModel = AudioRootViewModel(storage: makeStorage(hasUsable: true))
        let observer = AudioStorageObserver(
            storage: AudioRootStorageCapabilityAdapter(storage: provider),
            viewModel: viewModel
        )
        observer.cancel()
        observer.cancel()
        #expect(true)
    }
}

// MARK: - AudioPlugin 元数据

@MainActor
struct AudioPluginMetadataTests {
    @Test
    func pluginExposesStableIdentityAndPresentation() {
        let plugin = AudioPlugin.shared

        #expect(plugin.id == "AudioPlugin")
        #expect(plugin.order == 1)
        #expect(plugin.iconName == "music.note")
    }

    @Test
    func metadataCarriesExpectedLocalizationAndStage() {
        let metadata = AudioPlugin.shared.metadata

        #expect(metadata.id == "AudioPlugin")
        #expect(metadata.name == "Music")
        #expect(metadata.description == "Audio playback")
        #expect(metadata.version == "1.0.0")
        #expect(metadata.category == .feature)
        #expect(metadata.stage == .stable)
        #expect(metadata.policy == .disabled)
        #expect(metadata.permissions.isEmpty)
    }

    @Test
    func pluginReexportsInfoConstants() {
        #expect(AudioPlugin.maxAudioCount == 100)
        #expect(AudioPlugin.supportedExtensions.contains("mp3"))
        #expect(AudioPlugin.supportedExtensions.contains("m4a"))
        #expect(AudioPlugin.supportedExtensions.contains("flac"))
        #expect(AudioPlugin.dbDirName == "audios" || AudioPlugin.dbDirName == "audios_debug")
    }
}
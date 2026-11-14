import Combine
import Foundation
import Testing
import CisumProviderStorage

@Test(arguments: [
    (StorageLocation.icloud, "icloud", "🌐 iCloud", "🌐", "iCloud", "Store data in iCloud, synced across devices"),
    (StorageLocation.local, "local", "💾 Local", "💾", "Local", "Store data locally on this device"),
    (StorageLocation.custom, "custom", "🔧 Custom", "🔧", "Custom", "Use a custom storage location"),
])
func storageLocationPresentationAndPersistedValueRemainStable(
    location: StorageLocation,
    rawValue: String,
    emojiTitle: String,
    emoji: String,
    title: String,
    description: String
) throws {
    #expect(location.rawValue == rawValue)
    #expect(location.emojiTitle == emojiTitle)
    #expect(location.emoji == emoji)
    #expect(location.title == title)
    #expect(location.description == description)
    #expect(try JSONDecoder().decode(StorageLocation.self, from: JSONEncoder().encode(location)) == location)
}

@Test(arguments: ["icloud", "local", "custom"])
func storageLocationDecodesLegacyRawValues(rawValue: String) throws {
    #expect(try JSONDecoder().decode(StorageLocation.self, from: JSONEncoder().encode(rawValue)) == StorageLocation(rawValue: rawValue))
}

@Test(arguments: ["\"unknown\"", "\"iCloud\"", "\"\"", "null", "123", "{}"])
func storageLocationRejectsInvalidPersistedValues(json: String) {
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(StorageLocation.self, from: Data(json.utf8))
    }
}

@Test
func storageLocationCaseOrderRemainsStable() {
    #expect(StorageLocation.allCases == [.icloud, .local, .custom])
    #expect(StorageLocation(rawValue: "unknown") == nil)
}

@MainActor
private final class StorageProviderStub: @preconcurrency StorageProviding {
    let objectWillChange = ObservableObjectPublisher()
    var currentStorageLocation: StorageLocation? { nil }
    var storageRoot: URL? { nil }
    var hasUsableStorageLocation: Bool { false }
    var isICloudStorageAvailable: Bool { false }
    var databaseRoot: URL { URL(fileURLWithPath: "/unused") }
    func storageRoot(for location: StorageLocation) -> URL? { nil }
    func databaseFile(name: String) throws -> URL { databaseRoot }
    func pluginDataDirectory(for pluginID: String) -> URL { databaseRoot }
    func setStorageLocation(_ location: StorageLocation?) {}
    func resetStorageLocation() {}
}

@MainActor @Test
func defaultStorageObserverUsesNoopFallback() {
    let provider: any StorageProviding = StorageProviderStub()
    let handle = provider.addObserver { _ in
        Issue.record("默认观察者不应收到事件")
    }
    #expect(handle is NoopStorageProvidingObserverHandle)
    provider.setStorageLocation(.local)
    provider.resetStorageLocation()
    handle.cancel()
    handle.cancel()
}

@MainActor @Test
func explicitStorageNoopSupportsRepeatedCancellation() {
    let handle: any StorageProvidingObserverHandle = NoopStorageProvidingObserverHandle()
    handle.cancel()
    handle.cancel()
}

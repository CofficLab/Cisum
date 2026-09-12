import Foundation
import Testing
@testable import ProviderStorage

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

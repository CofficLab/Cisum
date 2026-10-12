import Foundation
import ProviderScene
import Testing
@testable import PluginPlayBack

@MainActor
struct PlaybackStateStoreTests {
    @Test
    func sceneFilesPersistIndependentlyAndDeleteWhenAllAreCleared() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PlaybackStateStore(rootDirectory: root)
        let musicURL = URL(fileURLWithPath: "/library/music.mp3")
        let audiobookURL = URL(fileURLWithPath: "/library/book.mp3")

        #expect(store.loadCurrentFile(for: .music) == nil)
        store.saveCurrentFile(musicURL, for: .music)
        store.saveCurrentFile(audiobookURL, for: .audiobooks)

        #expect(store.loadCurrentFile(for: .music) == musicURL)
        #expect(store.loadCurrentFile(for: .audiobooks) == audiobookURL)

        store.saveCurrentFile(nil, for: .music)
        #expect(store.loadCurrentFile(for: .music) == nil)
        #expect(store.loadCurrentFile(for: .audiobooks) == audiobookURL)

        store.saveCurrentFile(nil, for: .audiobooks)
        #expect(!FileManager.default.fileExists(atPath: storeFileURL(root).path))
    }

    @Test
    func legacyGlobalRecordMigratesOnceToTheFirstRequestedScene() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let legacyURL = URL(fileURLWithPath: "/legacy/last-played.mp3")
        try writePropertyList(["url": legacyURL.absoluteString], root: root)
        let store = PlaybackStateStore(rootDirectory: root)

        #expect(store.loadCurrentFile(for: .music) == legacyURL)
        #expect(readPropertyList(root: root) == [AppScene.music.rawValue: legacyURL.absoluteString])
        #expect(store.loadCurrentFile(for: .audiobooks) == nil)
    }

    @Test
    func savingSceneSpecificRecordDiscardsUnmigratedLegacyValue() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let legacyURL = URL(fileURLWithPath: "/legacy/last-played.mp3")
        let musicURL = URL(fileURLWithPath: "/library/music.mp3")
        try writePropertyList(["url": legacyURL.absoluteString], root: root)
        let store = PlaybackStateStore(rootDirectory: root)

        store.saveCurrentFile(musicURL, for: .music)

        #expect(store.loadCurrentFile(for: .music) == musicURL)
        #expect(store.loadCurrentFile(for: .audiobooks) == nil)
        #expect(readPropertyList(root: root) == [AppScene.music.rawValue: musicURL.absoluteString])
    }

    @Test
    func sceneSpecificRecordTakesPriorityAndPurgesCoexistingLegacyValue() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let legacyURL = URL(fileURLWithPath: "/legacy/last-played.mp3")
        let musicURL = URL(fileURLWithPath: "/library/music.mp3")
        try writePropertyList([
            "url": legacyURL.absoluteString,
            AppScene.music.rawValue: musicURL.absoluteString,
        ], root: root)
        let store = PlaybackStateStore(rootDirectory: root)

        #expect(store.loadCurrentFile(for: .music) == musicURL)
        #expect(readPropertyList(root: root) == [AppScene.music.rawValue: musicURL.absoluteString])
        #expect(store.loadCurrentFile(for: .audiobooks) == nil)
    }

    @Test
    func missingOrMalformedStateReturnsNil() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PlaybackStateStore(rootDirectory: root)

        #expect(store.loadCurrentFile(for: .music) == nil)
        try FileManager.default.createDirectory(at: storeFileURL(root).deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not a plist".utf8).write(to: storeFileURL(root))
        #expect(store.loadCurrentFile(for: .music) == nil)
    }

    @Test
    func writeFailureDoesNotEscapeIntoPlayback() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginPlayBackTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("root is a file".utf8).write(to: root)
        let store = PlaybackStateStore(rootDirectory: root)

        store.saveCurrentFile(URL(fileURLWithPath: "/library/current.mp3"), for: .music)

        #expect(store.loadCurrentFile(for: .music) == nil)
    }
}

private func temporaryRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginPlayBackTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func storeFileURL(_ root: URL) -> URL {
    root.appendingPathComponent("PluginPlayBack", isDirectory: true)
        .appendingPathComponent("current-playback.plist")
}

private func writePropertyList(_ dictionary: [String: String], root: URL) throws {
    try FileManager.default.createDirectory(at: storeFileURL(root).deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .binary, options: 0)
    try data.write(to: storeFileURL(root))
}

private func readPropertyList(root: URL) -> [String: String]? {
    guard let data = try? Data(contentsOf: storeFileURL(root)) else { return nil }
    return try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String]
}

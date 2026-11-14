import Foundation
import ProviderScene
import Testing
@testable import PluginPlayBack

@MainActor
struct PlaybackStateStoreTests {
    @Test
    func sceneFilesPersistIndependentlyAndDeleteWhenAllAreCleared() throws {
        let pluginDir = try temporaryPluginDirectory()
        defer { try? FileManager.default.removeItem(at: pluginDir.deletingLastPathComponent()) }
        let store = PlaybackStateStore(pluginDirectory: pluginDir)
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
        #expect(!FileManager.default.fileExists(atPath: storeFileURL(pluginDir).path))
    }

    @Test
    func legacyGlobalRecordMigratesOnceToTheFirstRequestedScene() throws {
        let pluginDir = try temporaryPluginDirectory()
        defer { try? FileManager.default.removeItem(at: pluginDir.deletingLastPathComponent()) }
        let legacyURL = URL(fileURLWithPath: "/legacy/last-played.mp3")
        try writePropertyList(["url": legacyURL.absoluteString], root: pluginDir)
        let store = PlaybackStateStore(pluginDirectory: pluginDir)

        #expect(store.loadCurrentFile(for: .music) == legacyURL)
        #expect(readPropertyList(root: pluginDir) == [AppScene.music.rawValue: legacyURL.absoluteString])
        #expect(store.loadCurrentFile(for: .audiobooks) == nil)
    }

    @Test
    func savingSceneSpecificRecordDiscardsUnmigratedLegacyValue() throws {
        let pluginDir = try temporaryPluginDirectory()
        defer { try? FileManager.default.removeItem(at: pluginDir.deletingLastPathComponent()) }
        let legacyURL = URL(fileURLWithPath: "/legacy/last-played.mp3")
        let musicURL = URL(fileURLWithPath: "/library/music.mp3")
        try writePropertyList(["url": legacyURL.absoluteString], root: pluginDir)
        let store = PlaybackStateStore(pluginDirectory: pluginDir)

        store.saveCurrentFile(musicURL, for: .music)

        #expect(store.loadCurrentFile(for: .music) == musicURL)
        #expect(store.loadCurrentFile(for: .audiobooks) == nil)
        #expect(readPropertyList(root: pluginDir) == [AppScene.music.rawValue: musicURL.absoluteString])
    }

    @Test
    func sceneSpecificRecordTakesPriorityAndPurgesCoexistingLegacyValue() throws {
        let pluginDir = try temporaryPluginDirectory()
        defer { try? FileManager.default.removeItem(at: pluginDir.deletingLastPathComponent()) }
        let legacyURL = URL(fileURLWithPath: "/legacy/last-played.mp3")
        let musicURL = URL(fileURLWithPath: "/library/music.mp3")
        try writePropertyList([
            "url": legacyURL.absoluteString,
            AppScene.music.rawValue: musicURL.absoluteString,
        ], root: pluginDir)
        let store = PlaybackStateStore(pluginDirectory: pluginDir)

        #expect(store.loadCurrentFile(for: .music) == musicURL)
        #expect(readPropertyList(root: pluginDir) == [AppScene.music.rawValue: musicURL.absoluteString])
        #expect(store.loadCurrentFile(for: .audiobooks) == nil)
    }

    @Test
    func missingOrMalformedStateReturnsNil() throws {
        let pluginDir = try temporaryPluginDirectory()
        defer { try? FileManager.default.removeItem(at: pluginDir.deletingLastPathComponent()) }
        let store = PlaybackStateStore(pluginDirectory: pluginDir)

        #expect(store.loadCurrentFile(for: .music) == nil)
        try FileManager.default.createDirectory(at: pluginDir, withIntermediateDirectories: true)
        try Data("not a plist".utf8).write(to: storeFileURL(pluginDir))
        #expect(store.loadCurrentFile(for: .music) == nil)
    }

    @Test
    func writeFailureDoesNotEscapeIntoPlayback() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginPlayBackTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("root is a file".utf8).write(to: root)
        let store = PlaybackStateStore(pluginDirectory: root)

        store.saveCurrentFile(URL(fileURLWithPath: "/library/current.mp3"), for: .music)

        #expect(store.loadCurrentFile(for: .music) == nil)
    }
}

private func temporaryPluginDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginPlayBackTests-\(UUID().uuidString)", isDirectory: true)
    let pluginDir = root.appendingPathComponent("PluginPlayBack", isDirectory: true)
    try FileManager.default.createDirectory(at: pluginDir, withIntermediateDirectories: true)
    return pluginDir
}

private func storeFileURL(_ pluginDir: URL) -> URL {
    pluginDir.appendingPathComponent("current-playback.plist")
}

private func writePropertyList(_ dictionary: [String: String], root pluginDir: URL) throws {
    try FileManager.default.createDirectory(at: pluginDir, withIntermediateDirectories: true)
    let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .binary, options: 0)
    try data.write(to: storeFileURL(pluginDir))
}

private func readPropertyList(root pluginDir: URL) -> [String: String]? {
    guard let data = try? Data(contentsOf: storeFileURL(pluginDir)) else { return nil }
    return try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String]
}

import Combine
import Foundation
import KernelCore
import ProviderPlugin
import Testing
@testable import ProviderScene

@MainActor
private final class SceneProviderStub: @preconcurrency SceneProviding {
    let objectWillChange = ObservableObjectPublisher()
    let scenes = AppScene.allCases
    private(set) var currentScene: AppScene?

    init(currentScene: AppScene?) {
        self.currentScene = currentScene
    }

    func setCurrentScene(_ scene: AppScene) {
        currentScene = scene
    }

    func restoreCurrentScene() {
        currentScene = scenes.first
    }
}

@MainActor
struct SceneProvidingTests {
    @Test
    func appScenesKeepStablePersistenceAndPresentationValues() throws {
        #expect(AppScene.allCases.map(\.rawValue) == ["Music Library", "Audiobooks"])
        #expect(AppScene.allCases.map(\.id) == ["Music Library", "Audiobooks"])
        #expect(AppScene.music.displayName == "Music Library")
        #expect(AppScene.audiobooks.displayName == "Audiobooks")
        #expect(AppScene.music.iconName == "music.note.list")
        #expect(AppScene.audiobooks.iconName == "book.closed")
        #expect(AppScene.music.order == 0)
        #expect(AppScene.audiobooks.order == 1)

        for scene in AppScene.allCases {
            let data = try JSONEncoder().encode(scene)
            #expect(try JSONDecoder().decode(AppScene.self, from: data) == scene)
        }
    }

    @Test
    func accessibilityIdentifiersRemainStableAndUnique() {
        #expect(AppScene.allCases.map(\.accessibilityID) == ["music", "audiobooks"])
        #expect(Set(AppScene.allCases.map(\.accessibilityID)).count == AppScene.allCases.count)
        #expect(AppScene.allCases.sorted { $0.order < $1.order } == [.music, .audiobooks])
    }

    @Test(arguments: [("\"Music Library\"", AppScene.music), ("\"Audiobooks\"", AppScene.audiobooks)])
    func legacyJSONDecodesWithoutMigration(json: String, expected: AppScene) throws {
        #expect(try JSONDecoder().decode(AppScene.self, from: Data(json.utf8)) == expected)
        #expect(try JSONEncoder().encode(expected) == Data(json.utf8))
    }

    @Test(arguments: ["\"music\"", "\"audiobooks\"", "\"removed-scene\"", "\"\"", "null", "0"])
    func invalidPersistedScenesDoNotSilentlySelectMusic(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AppScene.self, from: Data(json.utf8))
        }
    }

    @Test
    func kernelSceneAccessorResolvesRegisteredProvider() throws {
        let kernel = KernelCoreContainer()

        #expect(kernel.resolveProvider((any SceneProviding).self) == nil)

        let provider = SceneProviderStub(currentScene: .music)
        try kernel.registerProvider((any SceneProviding).self, provider)

        #expect(kernel.resolveProvider((any SceneProviding).self)?.currentScene == .music)
        #expect(kernel.resolveProvider((any SceneProviding).self)?.scenes == AppScene.allCases)
    }

    @Test
    func duplicateRegistrationRequiresExplicitUnregister() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any SceneProviding).self, SceneProviderStub(currentScene: .music))

        #expect(throws: KernelCoreError.self) {
            try kernel.registerProvider((any SceneProviding).self, SceneProviderStub(currentScene: .audiobooks))
        }

        kernel.unregisterProvider((any SceneProviding).self)
        try kernel.registerProvider((any SceneProviding).self, SceneProviderStub(currentScene: .audiobooks))
        #expect(kernel.resolveProvider((any SceneProviding).self)?.currentScene == .audiobooks)
    }

    @Test
    func defaultObserverUsesNoopFallback() {
        let provider = SceneProviderStub(currentScene: .music)
        let handle = provider.addObserver { _ in
            Issue.record("The default scene observer must not receive events")
        }

        #expect(handle is NoopSceneProvidingObserverHandle)
        handle.cancel()
        handle.cancel()
    }

    @Test
    func explicitNoopHandleSupportsRepeatedCancellation() {
        let handle = NoopSceneProvidingObserverHandle()

        handle.cancel()
        handle.cancel()
    }
}

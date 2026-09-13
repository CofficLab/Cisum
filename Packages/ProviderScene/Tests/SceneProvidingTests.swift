import Combine
import Foundation
import KernelCore
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
    func kernelSceneAccessorResolvesRegisteredProvider() throws {
        let kernel = CisumKernelContainer()

        #expect(kernel.scene == nil)

        let provider = SceneProviderStub(currentScene: .music)
        try kernel.registerSceneService(provider)

        #expect(kernel.scene?.currentScene == .music)
        #expect(kernel.scene?.scenes == AppScene.allCases)
    }

    @Test
    func duplicateRegistrationRequiresExplicitUnregister() throws {
        let kernel = CisumKernelContainer()
        try kernel.registerSceneService(SceneProviderStub(currentScene: .music))

        #expect(throws: CisumKernelError.self) {
            try kernel.registerSceneService(SceneProviderStub(currentScene: .audiobooks))
        }

        kernel.unregisterProvider((any SceneProviding).self)
        try kernel.registerSceneService(SceneProviderStub(currentScene: .audiobooks))
        #expect(kernel.scene?.currentScene == .audiobooks)
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

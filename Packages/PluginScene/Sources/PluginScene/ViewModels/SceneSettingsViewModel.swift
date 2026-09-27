import Combine
import Foundation
import ProviderScene
import MagicKit

@MainActor
final class SceneSettingsViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var revision = 0

    private weak var sceneProvider: (any SceneProviding)?
    private var currentScenes: [AppScene] = []
    private var selectedScene: AppScene?

    init(sceneProvider: (any SceneProviding)?) {
        self.sceneProvider = sceneProvider
        refresh()
    }

    var scenes: [AppScene] { sceneProvider == nil ? [] : currentScenes }
    var currentScene: AppScene? { sceneProvider == nil ? nil : selectedScene }

    var currentSceneIconName: String {
        currentScene?.iconName ?? "rectangle.3.group"
    }

    func select(_ target: AppScene) {
        sceneProvider?.setCurrentScene(target)
        refresh()
    }

    func handleProviderChanged() {
        refresh()
    }

    private func refresh() {
        currentScenes = sceneProvider?.scenes ?? []
        selectedScene = sceneProvider?.currentScene
        revision &+= 1
    }
}

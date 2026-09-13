import CisumUIComponents
import ProviderScene
import SwiftUI

struct AudioScenePluginPosterView: View {
    private let setCurrentScene: @MainActor (AppScene) -> Void
    private let dismissPoster: @MainActor () -> Void

    init(
        setCurrentScene: @escaping @MainActor (AppScene) -> Void,
        dismissPoster: @escaping @MainActor () -> Void = {}
    ) {
        self.setCurrentScene = setCurrentScene
        self.dismissPoster = dismissPoster
    }

    var body: some View {
        AudioPosterView(
            enterScene: {
                setCurrentScene(.music)
            },
            dismissPoster: dismissPoster
        )
    }
}

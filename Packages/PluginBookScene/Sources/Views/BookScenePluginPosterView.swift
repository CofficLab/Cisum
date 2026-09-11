import CisumUIComponents
import ProviderScene
import SwiftUI

struct BookScenePluginPosterView: View {
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
        BookPosterView(
            enterScene: {
                setCurrentScene(.audiobooks)
            },
            dismissPoster: dismissPoster
        )
    }
}

import CisumUIComponents
import LumiUI
import SwiftUI

struct AudioLikePluginRootView<Content>: View where Content: View {
    private let viewModel: AudioLikeViewModel
    private let content: Content

    init(viewModel: AudioLikeViewModel, @ViewBuilder content: () -> Content) {
        self.viewModel = viewModel
        self.content = content()
    }

    var body: some View {
        AudioLikeRootView(
            viewModel: viewModel
        ) {
            content
        }
    }
}

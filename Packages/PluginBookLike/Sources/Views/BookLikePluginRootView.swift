import CisumUIComponents
import LumiUI
import SwiftUI

struct BookLikePluginRootView<Content>: View where Content: View {
    private let viewModel: BookLikeViewModel
    private let content: Content

    init(viewModel: BookLikeViewModel, @ViewBuilder content: () -> Content) {
        self.viewModel = viewModel
        self.content = content()
    }

    var body: some View {
        BookLikeRootView(
            viewModel: viewModel
        ) {
            content
        }
    }
}

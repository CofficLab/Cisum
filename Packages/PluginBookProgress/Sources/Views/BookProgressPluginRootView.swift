import CisumUIComponents
import OSLog
import ProviderBook
import ProviderBook
import SwiftUI

struct BookProgressPluginRootView<Content>: View where Content: View {
    private let viewModel: BookProgressViewModel
    private let content: Content

    init(viewModel: BookProgressViewModel, @ViewBuilder content: () -> Content) {
        self.viewModel = viewModel
        self.content = content()
    }

    var body: some View {
        BookProgressRootView(viewModel: viewModel) {
            content
        }
    }
}

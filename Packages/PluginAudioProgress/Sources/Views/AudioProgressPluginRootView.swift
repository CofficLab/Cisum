import CisumUIComponents
import LumiUI
import ProviderAudioLibrary
import SwiftUI

struct AudioProgressPluginRootView<Content>: View where Content: View {
    private let viewModel: AudioProgressViewModel
    private let content: Content

    init(viewModel: AudioProgressViewModel, @ViewBuilder content: () -> Content) {
        self.viewModel = viewModel
        self.content = content()
    }

    var body: some View {
        AudioProgressRootView(viewModel: viewModel) {
            content
        }
    }
}

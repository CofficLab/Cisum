import CisumUIComponents
import SwiftUI

struct AudioSettingsPluginView: View {
    @ObservedObject private var viewModel: AudioSettingsViewModel

    init(viewModel: AudioSettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        AudioSettingsView(viewModel: viewModel)
    }
}

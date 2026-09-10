import CisumUIComponents
import SwiftUI

struct AudioSettingsPluginView: View {
    @ObservedObject private var viewModel: AudioSettingsViewModel
    private let audioDisk: @MainActor () -> URL?

    init(viewModel: AudioSettingsViewModel, audioDisk: @escaping @MainActor () -> URL?) {
        self.viewModel = viewModel
        self.audioDisk = audioDisk
    }

    var body: some View {
        AudioSettingsView(refreshToken: viewModel.refreshToken) {
            audioDisk()
        }
    }
}

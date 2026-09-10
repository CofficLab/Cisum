import CisumUIComponents
import ProviderBook
import SwiftUI

struct BookSettingsPluginView: View {
    @ObservedObject private var viewModel: BookSettingsViewModel

    init(viewModel: BookSettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        BookSettingsView(refreshToken: viewModel.refreshToken) {
            viewModel.bookDisk()
        }
    }
}

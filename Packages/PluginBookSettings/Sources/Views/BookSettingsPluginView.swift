import CisumUIComponents
import LumiUI
import ProviderBook
import SwiftUI

struct BookSettingsPluginView: View {
    @ObservedObject private var viewModel: BookSettingsViewModel

    init(viewModel: BookSettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        BookSettingsView(viewModel: viewModel)
    }
}

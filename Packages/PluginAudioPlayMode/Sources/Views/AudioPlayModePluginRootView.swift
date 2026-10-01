import CisumUIComponents
import LumiUI
import ProviderAudioLibrary
import SwiftUI

struct AudioPlayModePluginRootView<Content>: View where Content: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        AudioPlayModeRootView {
            content
        }
    }
}

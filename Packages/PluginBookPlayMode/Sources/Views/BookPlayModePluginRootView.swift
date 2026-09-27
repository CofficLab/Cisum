import CisumUIComponents
import LumiUI
import SwiftUI

struct BookPlayModePluginRootView<Content>: View where Content: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        BookPlayModeRootView {
            content
        }
    }
}

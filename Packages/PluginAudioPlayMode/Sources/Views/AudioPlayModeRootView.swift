import MagicKit
import CisumUIComponents
import LumiUI
import SwiftUI

public struct AudioPlayModeRootView<Content>: View, SuperLog where Content: View {
    public nonisolated static var emoji: String { AudioPlayModePluginInfo.emoji }
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View { content }
}

public extension Notification.Name {
    static let AudioPlayModeChanged = Notification.Name("AudioPlayModeChanged")
}

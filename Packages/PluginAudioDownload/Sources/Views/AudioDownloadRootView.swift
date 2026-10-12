import MagicKit
import CisumUIComponents
import LumiUI
import SwiftUI

public struct AudioDownloadRootView<Content>: View, SuperLog where Content: View {
    public nonisolated static var emoji: String { "⬇️" }
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View { content }
}

import MagicKit
import Foundation
import CisumUIComponents
import LumiUI
import SwiftUI

public struct AudioLikeRootView<Content>: View, SuperLog where Content: View {
    public nonisolated static var emoji: String { AudioLikePluginInfo.emoji }

    @ObservedObject private var viewModel: AudioLikeViewModel

    private let content: Content

    init(
        viewModel: AudioLikeViewModel,
        @ViewBuilder content: () -> Content
    ) {
        self.viewModel = viewModel
        self.content = content()
    }

    public var body: some View {
        content
    }
}

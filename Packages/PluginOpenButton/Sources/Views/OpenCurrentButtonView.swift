import MagicKit
// 系统工具栏会自动加样式，所以用原生 Button 最好，不要用自定义按钮组件。

import CisumUIComponents
import LumiUI
import SwiftUI

public struct OpenCurrentButtonView: View, SuperLog {
    public nonisolated static let emoji = "😜"
    public static let verbose = false
    nonisolated static let accessibilityTitle = String(localized: "Show in Finder", bundle: .module)
    public static var order: Int { 20 }

    @ObservedObject private var viewModel: OpenButtonViewModel

    init(viewModel: OpenButtonViewModel) { self.viewModel = viewModel }

    public var body: some View {
        Group {
            if let url = viewModel.url, Self.shouldShowOpenButton(for: url) {
                Button(Self.accessibilityTitle, systemImage: .cisumIconShowInFinder) {
                    url.openInFinder()
                }
                .accessibilityLabel(Text(Self.accessibilityTitle))
                .accessibilityRepresentation {
                    Button(Self.accessibilityTitle) {}
                }
                .help(Text(Self.accessibilityTitle))
                .id(url.absoluteString)
            }
        }
    }

    nonisolated static func shouldShowOpenButton(
        for url: URL,
        fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:)
    ) -> Bool {
        url.isFileURL && fileExists(url.path)
    }
}

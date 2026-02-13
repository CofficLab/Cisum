import MagicKit
import OSLog
import SwiftUI

actor OpenButtonPlugin: SuperPlugin, SuperLog {
    let description: String = "当前资源打开按钮"
    let iconName: String = .iconFinder
    static var shouldRegister: Bool { true }
    static var verbose: Bool { true }
    nonisolated static let emoji = "😜"

    #if os(macOS)
        @MainActor
        func addToolBarButtons() -> [(id: String, view: AnyView)] {
            return [(id: "open-current", view: AnyView(OpenCurrentButtonView()))]
        }
    #endif
}

private struct OpenCurrentButtonView: View, SuperLog {
    nonisolated static let emoji = "😜"
    static let verbose = false
    /// 注册顺序设为 20，在其他插件之后执行
    static var order: Int { 20 }
    @EnvironmentObject var man: PlayMan

    @State private var url: URL? = nil

    var body: some View {
        if Self.verbose {
            os_log("\(self.t)开始渲染")
        }
        return Group {
            if let url = url {
                Image(systemName: .iconShowInFinder)
                    .frame(width: 28)
                    .frame(height: 28)
                    .background(.regularMaterial, in: .circle)
                    .shadowSm()
                    .hoverScale(105)
                    .inButtonWithAction {
                        url.openInFinder()
                    }
                    .id(url.absoluteString)
            }
        }
        .onPlayManAssetChanged({
            self.url = $0
        })
        .onAppear {
            if let url = man.asset {
                self.url = url
            }
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

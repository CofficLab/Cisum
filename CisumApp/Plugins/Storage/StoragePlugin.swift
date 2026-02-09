import Foundation
import MagicKit

import OSLog
import SwiftUI

actor StoragePlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "💾"
    static let verbose = true
    static var shouldRegister: Bool { false }

    /// 注册顺序设为 10，在其他插件之后执行
    static var order: Int { 10 }

    let title = "存储设置"
    let description = "存储设置"
    let iconName = "internaldrive"
    

    @MainActor
    func addSettingView() -> AnyView? {
        if Self.verbose {
            os_log("\(self.t)💾 加载存储设置视图")
        }

        return AnyView(StorageSettingView())
    }
}


#Preview("Setting") {
    RootView {
        SettingView()
            .background(.background)
    }
    .frame(height: 800)
}

// MARK: - Preview

#if os(macOS)
#Preview("App - Large") {
    ContentView()
    .inRootView()
        .frame(width: 600, height: 1000)
}

#Preview("App - Small") {
    ContentView()
    .inRootView()
        .frame(width: 500, height: 800)
}
#endif

#if os(iOS)
#Preview("iPhone") {
    ContentView()
    .inRootView()
}
#endif

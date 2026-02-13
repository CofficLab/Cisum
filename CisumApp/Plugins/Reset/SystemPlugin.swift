import Foundation
import MagicKit
import OSLog
import SwiftUI

actor SystemPlugin: SuperPlugin, SuperLog {
    static let emoji = "⚙️"
    static let verbose = false
    static var shouldRegister: Bool { true }

    /// 注册顺序设为 90，在其他插件之后执行
    static var order: Int { 90 }

    let title = "系统"
    let description = "系统设置"
    let iconName = "gearshape"

    @MainActor
    func addSettingView() -> AnyView? {
        return AnyView(SystemSetting())
    }
}

// MARK: Preview

#Preview("ResetConfirm") {
    RootView {
        ResetConfirm()
            .padding()
            .frame(width: 400)
    }
}

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

#if os(iOS)
    #Preview("iPhone") {
        ContentView()
            .inRootView()
    }
#endif

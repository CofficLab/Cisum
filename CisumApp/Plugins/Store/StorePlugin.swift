import Foundation
import MagicKit
import OSLog
import SwiftUI

actor StorePlugin: SuperPlugin {
    static var shouldRegister: Bool { true }
    static var order: Int { 80 }

    let title = "商店"
    let description = "应用内购买和订阅"
    let iconName = "cart"

    @MainActor
    func addSettingView() -> AnyView? {
        AnyView(StoreSetting())
    }
}

#Preview("App - Large") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

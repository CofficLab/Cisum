import Foundation
import MagicKit
import OSLog
import SwiftUI

actor StorePlugin: SuperPlugin {
    static var shouldRegister: Bool { true }
    static var order: Int { 80 }

    let title = "Store"
    let description = "In-App purchases and subscriptions"
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

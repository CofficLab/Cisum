#if !os(macOS)
import FactoryCisum
import SwiftUI

/// iOS / iPadOS 应用入口：只做场景组装，窗口内容由 Factory 提供。
struct CisumIOSApp: App {
    var body: some Scene {
        WindowGroup(AppBootstrap.appName, id: AppBootstrap.mainWindowID) {
            FactoryCisum.makeMainWindow(configuration: CisumAppAssembly.configuration)
        }
    }
}
#endif

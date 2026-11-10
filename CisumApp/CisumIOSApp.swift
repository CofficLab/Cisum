#if !os(macOS)
import FactoryCisum
import SwiftUI

/// iOS / iPadOS / visionOS 应用入口：只做场景组装，窗口内容由 Factory 提供。
///
/// visionOS 与 iOS 走同一条路径：两者都是 SwiftUI + UIKit 的窗口式应用，
/// 主窗口（`WindowGroup`）与设置 sheet 的装配方式一致。
struct CisumIOSApp: App {
    var body: some Scene {
        WindowGroup(AppBootstrap.appName, id: AppBootstrap.mainWindowID) {
            FactoryCisum.makeMainWindow(configuration: CisumAppAssembly.configuration)
        }
    }
}
#endif

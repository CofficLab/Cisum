import MagicKit
import OSLog
import SwiftUI

/**
 * 有声书设置插件，提供仓库信息展示。
 *
 * 复用 `BookSettings` 视图，不重新创建仓库或监听。
 */
actor BookSettingsPlugin: SuperPlugin {
    static var shouldRegister: Bool { false }
    static var order: Int { 11 }
    let title = "有声书设置"
    let description = "有声书插件的设置入口"
    let iconName = "gearshape"

    @MainActor
    func addSettingView() -> AnyView? {
        return AnyView(BookSettings())
    }
}

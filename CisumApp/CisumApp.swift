import FactoryCisum
import PluginStore
import SwiftUI

/// 宿主在编译期确定的内核组装配置。
///
/// 插件清单由 `FactoryCisum` 的 `DefaultPluginFactory` 直接装配（对齐 Lumi，
/// Factory 是唯一知道"应用由哪些插件组成"的地方），宿主不再注入插件列表。
@MainActor
enum CisumAppAssembly {
    static let configuration = FactoryCisumConfiguration()
}

/// 应用入口：按平台选择对应的实现，宿主级初始化只在此处执行一次。
///
/// - macOS: `CisumMacApp`（`NSApplicationDelegateAdaptor` + 设置窗口 + 命令菜单）
/// - iOS / iPadOS: `CisumIOSApp`
///
/// 对齐 GameFactory/BookletMakerApp 的平台拆分：入口、macOS 场景、iOS 场景
/// 各占一个文件，AppKit 等平台专属 API 由文件级 `#if` 隔离，避免跨平台编译
/// 时相互污染。
@main
struct CisumApp: App {
    init() {
        #if os(macOS)
        UserDefaults.standard.set(true, forKey: "ApplePersistenceIgnoreState")
        #endif
        StoreService.bootstrap()
    }

    var body: some Scene {
        #if os(macOS)
        CisumMacApp().body
        #else
        CisumIOSApp().body
        #endif
    }
}

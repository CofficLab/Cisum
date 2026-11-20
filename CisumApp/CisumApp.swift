import LumiFactory
import SwiftUI

/// 应用入口：单个 target，平台差异由 `#if` 隔离（对齐 Wakey `App.swift`）。
///
/// - macOS: 共享 `HostMacScenes`（主窗口 + 设置窗口 + 命令）
/// - iOS / iPadOS / visionOS: `WindowGroup` + `HostRootWindowView`
///   （标准设置壳：NavigationStack + 设置 sheet）
///
/// 装配流水线、窗口壳与生命周期协调全部由 LumiFactory 解释
/// `CisumManifest.manifest` 执行；本文件只负责把启动器接到 SwiftUI 入口。
@main
struct CisumApp: App {
    // delegate adaptor 必须挂在 @main 根 App 上：SwiftUI 只为根 App 安装
    // NSApplicationDelegateAdaptor。放在 body 里临时创建的嵌套结构上不会生效。
    #if os(macOS)
    @NSApplicationDelegateAdaptor private var appDelegate: HostAppDelegate
    #endif

    init() {
        #if os(macOS)
        // 禁用窗口状态恢复必须在根 App.init 写入（恢复发生在 delegate 回调之前）。
        HostAppDelegate.prepareForLaunch()
        appDelegate.bootstrapper = CisumAssembly.bootstrapper
        CisumMenuInstaller.shared.start()
        #endif
    }

    var body: some Scene {
        #if os(macOS)
        HostMacScenes(bootstrapper: CisumAssembly.bootstrapper).body
        #else
        WindowGroup("Cisum", id: "cisum.main") {
            HostRootWindowView(bootstrapper: CisumAssembly.bootstrapper)
        }
        #endif
    }
}

/// 宿主级装配单例：App.init 可能被 SwiftUI 多次求值，启动器必须经单例创建，
/// 保证视图持有的与注入 AppDelegate 的是同一个。
@MainActor
enum CisumAssembly {
    static let bootstrapper = KernelBootstrapper(manifest: CisumManifest.manifest)
}
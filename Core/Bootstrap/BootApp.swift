import MagicAlert
import MagicKit
import MagicPlayMan
import OSLog
import SwiftUI

typealias PlayMan = MagicPlayMan
typealias PlayAsset = MagicAsset
typealias PlayMode = MagicPlayMode
typealias MagicApp = MagicKit.MagicApp
typealias SuperLog = MagicKit.SuperLog
typealias MagicSettingSection = MagicKit.MagicSettingSection
typealias MagicSettingRow = MagicKit.MagicSettingRow

@main
struct BootApp: App, SuperLog {
    #if os(macOS)
        @NSApplicationDelegateAdaptor var appDelegate: AppDelegate
    #else
        @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    #endif

    nonisolated static let emoji = "🍎"

    init() {
        StoreService.bootstrap()
    }

    var body: some Scene {
        #if os(macOS)
            Window("", id: "Cisum") {
                ContentView()
                    .inRootView()
                    .frame(minWidth: Config.minWidth, minHeight: Config.minHeight)
            }
            .windowToolbarStyle(.unifiedCompact(showsTitle: false))
            .defaultSize(width: Config.minWidth, height: Config.defaultHeight)
            .commands {
                SidebarCommands()
                MagicApp.debugCommand()
            }
        #else
            WindowGroup {
                ContentView()
                    .inRootView()
            }
        #endif
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

#if os(macOS)
    import AppKit
    import CisumUIComponents
import LumiUI
    import SwiftUI

    /// macOS 应用代理（对齐 Lumi 的 `MacAgent`，由 App target 通过
    /// `@NSApplicationDelegateAdaptor` 采用）。
    ///
    /// 仅保留必要职责：禁用状态恢复，以及在 Dock 点击 / `open -a` 重新激活主窗口。
    @MainActor
    public final class AppDelegate: NSObject, NSApplicationDelegate {
        private var windowObservers: [NSObjectProtocol] = []

        public override init() {
            super.init()
        }

        deinit {
            windowObservers.forEach(NotificationCenter.default.removeObserver)
        }

        public func applicationDidFinishLaunching(_ notification: Notification) {
            windowObservers = [
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didBecomeKeyNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    self?.enforceMainWindowMinimumSize(from: notification)
                },
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didResizeNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    self?.enforceMainWindowMinimumSize(from: notification)
                },
            ]

            DispatchQueue.main.async { [weak self] in
                self?.enforceMainWindowMinimumSize()
            }
        }

        public func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
            false
        }

        public func application(_ app: NSApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
            false
        }

        public func application(_ app: NSApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
            false
        }

        public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
            if !flag, AppWindowController.showExistingMainWindow(in: sender) {
                return false
            }
            return true
        }

        private func enforceMainWindowMinimumSize(from notification: Notification? = nil) {
            let window = notification?.object as? NSWindow
                ?? NSApplication.shared.windows.first(where: AppWindowController.isMainAppWindow)

            guard let window, AppWindowController.isMainAppWindow(window) else { return }

            MainWindowMinimumSizeBridge.apply(
                to: window,
                minimumSize: CGSize(
                    width: CisumPlayerLayout.minimumWindowWidth,
                    height: CisumPlayerLayout.minimumWindowHeight
                )
            )
        }
    }

    /// 主窗口控制器：重新激活已存在的主窗口。
    @MainActor
    enum AppWindowController {
        static let mainWindowID = AppBootstrap.mainWindowID

        @discardableResult
        static func showExistingMainWindow(in app: NSApplication = .shared) -> Bool {
            guard let window = app.windows.first(where: isMainAppWindow) else { return false }

            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            app.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return true
        }

        static func isMainAppWindow(_ window: NSWindow) -> Bool {
            (window.isVisible || window.isMiniaturized)
                && window.canBecomeMain
                && window.level == .normal
                && (window.identifier?.rawValue == mainWindowID || window.title == AppBootstrap.appName)
        }
    }
#endif

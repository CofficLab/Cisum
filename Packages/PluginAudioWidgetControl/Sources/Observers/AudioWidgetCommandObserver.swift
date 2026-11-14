import CoreFoundation
import Foundation
import MagicKit

/// Widget 控制命令的集中观察者（迁移 Phase 4）。
///
/// 注册 Darwin 通知中心监听器（Widget → App 跨进程通信），并订阅
/// `.audioWidgetCommandReceived` 通知驱动 `AudioWidgetControlViewModel`
/// 处理命令；取代原 `AudioWidgetControlRootView` 的
/// `setupWidgetCommandListener()` + `.onReceive` 直接订阅。
@MainActor
final class AudioWidgetCommandObserver: SuperLog {
    nonisolated static let emoji = "📟"
    nonisolated static let verbose = false

    private weak var viewModel: AudioWidgetControlViewModel?
    private var token: NSObjectProtocol?
    private var darwinRegistered = false

    init(viewModel: AudioWidgetControlViewModel) {
        self.viewModel = viewModel
        setupDarwinListener()
        token = NotificationCenter.default.addObserver(
            forName: .audioWidgetCommandReceived,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.viewModel?.handleWidgetCommands()
            }
        }
    }

    func cancel() {
        if let token {
            NotificationCenter.default.removeObserver(token)
        }
        token = nil
    }

    private func setupDarwinListener() {
        guard !darwinRegistered else { return }
        darwinRegistered = true

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let callback: CFNotificationCallback = { _, _, _, _, _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .audioWidgetCommandReceived, object: nil)
            }
        }

        CFNotificationCenterAddObserver(
            center,
            nil,
            callback,
            "com.yueyi.cisum.widgetCommand" as CFString,
            nil,
            .deliverImmediately
        )
    }
}

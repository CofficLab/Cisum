import Foundation
import ProviderToast

/// 旧 `alert_*` API 的兼容桥接。
///
/// 新代码应直接解析 `ToastProviding`；保留这些入口是为了让现有插件在迁移期间
/// 仍然使用同一个全局 Toast Provider，而不是回到 MagicAlert 的独立单例。
@MainActor
public enum CisumToastBridge {
    private static var currentProvider: any ToastProviding = DefaultToastProvider()

    public static func install(_ provider: any ToastProviding) {
        currentProvider = provider
    }

    public static var provider: any ToastProviding {
        currentProvider
    }
}

@MainActor
public func alert_info(_ title: String, subtitle: String? = nil, duration: TimeInterval = 3) {
    CisumToastBridge.provider.show(
        CisumToast(title: title, detail: subtitle, style: .info, duration: duration)
    )
}

@MainActor
public func alert_success(_ title: String, subtitle: String? = nil, duration: TimeInterval = 3) {
    CisumToastBridge.provider.show(
        CisumToast(title: title, detail: subtitle, style: .success, duration: duration)
    )
}

@MainActor
public func alert_warning(_ title: String, subtitle: String? = nil, duration: TimeInterval = 4) {
    CisumToastBridge.provider.show(
        CisumToast(title: title, detail: subtitle, style: .warning, duration: duration)
    )
}

@MainActor
public func alert_error(
    _ title: String,
    subtitle: String? = nil,
    duration: TimeInterval = 0,
    autoDismiss: Bool = false
) {
    if autoDismiss || duration > 0 {
        CisumToastBridge.provider.show(
            CisumToast(
                title: title,
                detail: subtitle,
                style: .error,
                duration: duration > 0 ? duration : 3
            )
        )
    } else {
        CisumToastBridge.provider.presentError(title: title, message: subtitle ?? title)
    }
}

@MainActor
public func alert_error(
    _ error: Error,
    title: String? = nil,
    duration: TimeInterval = 0,
    autoDismiss: Bool = false
) {
    alert_error(
        title ?? "Error",
        subtitle: error.localizedDescription,
        duration: duration,
        autoDismiss: autoDismiss
    )
}

@MainActor
public func alert_loading(_ title: String, subtitle: String? = nil) {
    CisumToastBridge.provider.showLoading(title: title, detail: subtitle)
}

@MainActor
public func alert_dismiss_loading() {
    CisumToastBridge.provider.dismissLoading()
}

@MainActor
public func alert_dismiss_all() {
    CisumToastBridge.provider.dismissAll()
}

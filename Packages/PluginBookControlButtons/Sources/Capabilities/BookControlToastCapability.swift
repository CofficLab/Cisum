import Foundation
import ProviderToast

/// 有声书控制按钮的提示能力。
///
/// 内核 `ToastProviding` 提供全套提示，本插件只使用带窗口定位的持久化
/// 错误面板（`sourceWindowID` 决定在哪个窗口呈现）。
@MainActor
protocol BookControlToastCapability: AnyObject {
    /// 展示一条错误面板；`sourceWindowID` 决定在哪个窗口呈现，nil 表示来源未知。
    func presentError(title: String, message: String, sourceWindowID: String?)
}

/// 将内核 `ToastProviding` 收窄为有声书控制按钮的提示能力。
@MainActor
final class BookControlToastCapabilityAdapter: BookControlToastCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「不提示」而非延长其生命周期。
    private weak var toast: (any ToastProviding)?

    init(toast: (any ToastProviding)?) {
        self.toast = toast
    }

    func presentError(title: String, message: String, sourceWindowID: String?) {
        toast?.presentError(title: title, message: message, sourceWindowID: sourceWindowID)
    }
}
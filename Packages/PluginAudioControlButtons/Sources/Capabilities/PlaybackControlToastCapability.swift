import Foundation
import ProviderToast

/// 播放控制的提示能力。
///
/// 内核 `ToastProviding` 提供 success / warning / info / error 及带窗口定位的
/// `presentError` 等全套提示；控制按钮只用三种（见成员），故在此最小化。
@MainActor
protocol PlaybackControlToastCapability: AnyObject {
    /// 展示一条普通提示。
    func info(_ message: String)

    /// 展示一条警告提示。
    func warning(_ message: String)

    /// 展示一条错误面板；`sourceWindowID` 决定在哪个窗口呈现，nil 表示来源未知。
    func presentError(title: String, message: String, sourceWindowID: String?)
}

/// 将内核 `ToastProviding` 收窄为播放控制的提示能力。
@MainActor
final class PlaybackControlToastCapabilityAdapter: PlaybackControlToastCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「不提示」而非延长其生命周期。
    private weak var toast: (any ToastProviding)?

    init(toast: (any ToastProviding)?) {
        self.toast = toast
    }

    func info(_ message: String) {
        toast?.info(message)
    }

    func warning(_ message: String) {
        toast?.warning(message)
    }

    func presentError(title: String, message: String, sourceWindowID: String?) {
        toast?.presentError(title: title, message: message, sourceWindowID: sourceWindowID)
    }
}
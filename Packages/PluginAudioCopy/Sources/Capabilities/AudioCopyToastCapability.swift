import Foundation
import ProviderToast

/// 复制功能的提示能力。
///
/// 内核 `ToastProviding` 提供全套提示，复制功能只用两种：
/// 复制完成的 info 确认与失败时的 error。
@MainActor
protocol AudioCopyToastCapability: AnyObject {
    /// 展示一条普通提示。
    func info(_ message: String)

    /// 展示一条错误提示。
    func error(_ message: String)
}

/// 将内核 `ToastProviding` 收窄为复制功能的提示能力。
@MainActor
final class AudioCopyToastCapabilityAdapter: AudioCopyToastCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「不提示」而非延长其生命周期。
    private weak var toast: (any ToastProviding)?

    init(toast: (any ToastProviding)?) {
        self.toast = toast
    }

    func info(_ message: String) {
        toast?.info(message)
    }

    func error(_ message: String) {
        toast?.error(message)
    }
}
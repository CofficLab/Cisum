import Foundation
import ProviderToast

/// 引导的提示能力。
///
/// 内核 `ToastProviding` 提供 success / warning / info / error 等全套提示；
/// 本插件只用 error（操作失败）与 warning（部分跳过等可恢复问题），故在此最小化。
@MainActor
protocol GuideToastCapability: AnyObject {
    /// 展示一条错误提示。
    func error(_ message: String)

    /// 展示一条警告提示（操作未完全成功，但用户可继续）。
    func warning(_ message: String)
}

/// 将内核 `ToastProviding` 收窄为引导的提示能力。
@MainActor
final class GuideToastCapabilityAdapter: GuideToastCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时提示静默丢弃而非延长其生命周期。
    private weak var toast: (any ToastProviding)?

    init(toast: (any ToastProviding)?) {
        self.toast = toast
    }

    func error(_ message: String) {
        toast?.error(message)
    }

    func warning(_ message: String) {
        toast?.warning(message)
    }
}

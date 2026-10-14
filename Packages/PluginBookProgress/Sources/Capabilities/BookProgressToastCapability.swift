import Foundation
import ProviderToast

/// 书籍进度的提示能力。
///
/// 内核 `ToastProviding` 提供 success / warning / info / error 等全套提示，
/// 本插件只在下载失败时用 error，故最小化到单方法。
@MainActor
protocol BookProgressToastCapability: AnyObject {
    /// 展示一条错误提示。
    func error(_ message: String)
}

/// 将内核 `ToastProviding` 收窄为书籍进度的提示能力。
@MainActor
final class BookProgressToastCapabilityAdapter: BookProgressToastCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「不提示」而非延长其生命周期。
    private weak var toast: (any ToastProviding)?

    init(toast: (any ToastProviding)?) {
        self.toast = toast
    }

    func error(_ message: String) {
        toast?.error(message)
    }
}
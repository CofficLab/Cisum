import Foundation
import ProviderToast

/// 有声书库的错误提示能力。
///
/// 内核 `ToastProviding` 提供 success / warning / info / error 等全套提示，
/// 本插件只用 error（例如「没有可播放的章节」），故在此最小化。
@MainActor
protocol BookLibraryToastCapability: AnyObject {
    /// 展示一条错误提示。
    func error(_ message: String)
}

/// 将内核 `ToastProviding` 收窄为有声书库网格的提示能力。
@MainActor
final class BookLibraryToastCapabilityAdapter: BookLibraryToastCapability {
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
import ProviderToast

/// 音乐库的错误/提示能力。
///
/// 内核 `ToastProviding` 提供 success / warning / info / error 等全套提示；
/// 本插件只用 error（操作失败）与 info（操作成功摘要），故在此最小化。
@MainActor
protocol AudioLibraryToastCapability: AnyObject {
    /// 展示一条错误提示。
    func error(_ message: String)

    /// 展示一条普通提示。
    func info(_ message: String)
}

/// 将内核 `ToastProviding` 收窄为音乐库的提示能力。
@MainActor
final class AudioLibraryToastCapabilityAdapter: AudioLibraryToastCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「不提示」而非延长其生命周期。
    private weak var toast: (any ToastProviding)?

    init(toast: (any ToastProviding)?) {
        self.toast = toast
    }

    func error(_ message: String) {
        toast?.error(message)
    }

    func info(_ message: String) {
        toast?.info(message)
    }
}
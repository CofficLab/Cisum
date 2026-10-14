import ProviderToast

/// 音频喜欢按钮的提示能力。
///
/// 内核 `ToastProviding` 提供全套提示，本插件只在保存喜欢状态失败时用 error。
@MainActor
protocol AudioLikeToastCapability: AnyObject {
    /// 展示一条错误提示。
    func error(_ message: String)
}

/// 将内核 `ToastProviding` 收窄为音频喜欢的提示能力。
@MainActor
final class AudioLikeToastCapabilityAdapter: AudioLikeToastCapability {
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
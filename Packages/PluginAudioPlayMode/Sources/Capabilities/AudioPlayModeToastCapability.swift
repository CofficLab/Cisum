import ProviderToast

/// 音频播放模式按钮的提示能力。
///
/// 内核 `ToastProviding` 提供全套提示，本插件只用两种：
/// 切换模式时的 info 确认与队列重建失败时的 error。
@MainActor
protocol AudioPlayModeToastCapability: AnyObject {
    /// 展示一条普通提示。
    func info(_ message: String)

    /// 展示一条错误提示。
    func error(_ message: String)
}

/// 将内核 `ToastProviding` 收窄为播放模式按钮的提示能力。
@MainActor
final class AudioPlayModeToastCapabilityAdapter: AudioPlayModeToastCapability {
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
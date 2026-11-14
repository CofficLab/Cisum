import ProviderToast

/// 播放模式按钮的提示能力。
///
/// 内核 `ToastProviding` 提供 success / warning / info / error 及持久化错误面板等，
/// 本插件只在切换模式时给出 info 提示，故最小化到单方法。
@MainActor
protocol BookPlayModeToastCapability: AnyObject {
    /// 展示一条普通提示。
    func info(_ message: String)
}

/// 将内核 `ToastProviding` 收窄为播放模式按钮的提示能力。
@MainActor
final class BookPlayModeToastCapabilityAdapter: BookPlayModeToastCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「不提示」而非延长其生命周期。
    private weak var toast: (any ToastProviding)?

    init(toast: (any ToastProviding)?) {
        self.toast = toast
    }

    func info(_ message: String) {
        toast?.info(message)
    }
}
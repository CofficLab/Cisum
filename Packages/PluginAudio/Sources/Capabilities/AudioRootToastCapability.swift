import ProviderToast

/// 音乐根容器的提示能力。
///
/// 内核 `ToastProviding` 提供全套提示，根容器只在存储位置变化时给出
/// info 确认。
@MainActor
protocol AudioRootToastCapability: AnyObject {
    /// 展示一条普通提示。
    func info(_ message: String)
}

/// 将内核 `ToastProviding` 收窄为音乐根容器的提示能力。
@MainActor
final class AudioRootToastCapabilityAdapter: AudioRootToastCapability {
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
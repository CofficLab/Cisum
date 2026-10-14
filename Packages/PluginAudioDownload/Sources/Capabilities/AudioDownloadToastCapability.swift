import ProviderToast

/// 音频自动下载的提示能力。
///
/// 内核 `ToastProviding` 提供全套提示，下载器只在下载失败时用 error。
@MainActor
protocol AudioDownloadToastCapability: AnyObject {
    /// 展示一条错误提示。
    func error(_ message: String)
}

/// 将内核 `ToastProviding` 收窄为音频自动下载的提示能力。
@MainActor
final class AudioDownloadToastCapabilityAdapter: AudioDownloadToastCapability {
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
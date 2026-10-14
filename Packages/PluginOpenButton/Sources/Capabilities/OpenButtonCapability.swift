import Foundation
import ProviderPlayback

/// 打开按钮事件：只有「当前播放文件变化」。
@MainActor
enum OpenButtonEvent {
    /// 当前播放文件变化（`nil` 表示无播放）。
    case assetChanged(URL?)
}

/// 打开按钮监听句柄。
@MainActor
protocol OpenButtonObserverHandle: AnyObject {
    /// 停止接收后续播放文件变更通知。重复调用无副作用。
    func cancel()
}

/// 打开按钮所需的最小播放能力。
///
/// 按钮只显示「当前播放文件」入口，不消费播放控制、进度、收藏等其余能力。
@MainActor
protocol OpenButtonCapability: AnyObject {
    /// 当前播放文件；无播放时为 `nil`。
    var currentURL: URL? { get }

    /// 订阅当前文件变更；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (OpenButtonEvent) -> Void
    ) -> any OpenButtonObserverHandle
}

/// 将内核 `PlaybackProviding` 收窄为打开按钮的最小能力。
@MainActor
final class OpenButtonCapabilityAdapter: OpenButtonCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「无播放」而非延长其生命周期。
    private weak var playback: (any PlaybackProviding)?

    init(playback: (any PlaybackProviding)?) {
        self.playback = playback
    }

    var currentURL: URL? { playback?.currentURL }

    @discardableResult
    func addObserver(
        _ callback: @escaping (OpenButtonEvent) -> Void
    ) -> any OpenButtonObserverHandle {
        guard let playback else { return OpenButtonHandleBox(cancelAction: nil) }
        let handle = playback.addObserver { event in
            guard case let .assetChanged(url) = event else { return }
            callback(.assetChanged(url))
        }
        return OpenButtonHandleBox(cancelAction: handle.cancel)
    }
}

/// 将内核的 `PlaybackProvidingObserverHandle` 适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class OpenButtonHandleBox: OpenButtonObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: (() -> Void)?) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}
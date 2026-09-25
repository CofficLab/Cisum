import Foundation
import ProviderAppState
import ProviderAudioLibrary
import ProviderCloud
import ProviderDevice
import ProviderPlayback
import ProviderStorage
import ProviderTheme

/// Kernel 内部和默认 Provider 共用的弱生命周期事件分发器。
///
/// Provider 仍然拥有自己的事件枚举和 ObserverHandle，避免所有能力被压成一
/// 个无语义的 NotificationCenter；这个通用实现只负责句柄取消、弱生命周期和
/// 同步分发。
@MainActor
public final class KernelEventObserverStore<Event> {
    private var callbacks: [UUID: (Event) -> Void] = [:]

    public init() {}

    @discardableResult
    public func add(_ callback: @escaping (Event) -> Void) -> KernelEventObserverHandle<Event> {
        let id = UUID()
        callbacks[id] = callback
        return KernelEventObserverHandle(store: self, id: id)
    }

    public func send(_ event: Event) {
        let activeCallbacks = Array(callbacks.values)
        for callback in activeCallbacks {
            callback(event)
        }
    }

    fileprivate func remove(id: UUID) {
        callbacks.removeValue(forKey: id)
    }
}

@MainActor
public final class KernelEventObserverHandle<Event>: AnyObject {
    private weak var store: KernelEventObserverStore<Event>?
    private let id: UUID
    private var isCancelled = false

    fileprivate init(store: KernelEventObserverStore<Event>, id: UUID) {
        self.store = store
        self.id = id
    }

    public func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        store?.remove(id: id)
    }

}

extension KernelEventObserverHandle: AppStateProvidingObserverHandle {}
extension KernelEventObserverHandle: AudioLibraryProvidingObserverHandle {}
extension KernelEventObserverHandle: CloudProvidingObserverHandle {}
extension KernelEventObserverHandle: DeviceProvidingObserverHandle {}
extension KernelEventObserverHandle: PlaybackProvidingObserverHandle {}
extension KernelEventObserverHandle: StorageProvidingObserverHandle {}
extension KernelEventObserverHandle: ThemeProvidingObserverHandle {}
extension KernelEventObserverHandle: PluginProvidingObserverHandle {}

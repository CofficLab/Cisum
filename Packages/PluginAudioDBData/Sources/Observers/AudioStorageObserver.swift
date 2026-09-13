import MagicKit
import ProviderStorage

/// 音频数据层的存储变化观察者。
///
/// 统一持有 `StorageProviding` 的订阅句柄，并在数据层生命周期结束时
/// 取消订阅。具体响应由使用方注入：插件入口用于重启文件同步，
/// `AudioLibraryProvider` 用于丢弃旧 Repository。
@MainActor
final class AudioStorageObserver: SuperLog {
    nonisolated static let emoji = "📦"
    nonisolated static let verbose = false

    private var handle: (any StorageProvidingObserverHandle)?

    init(
        provider: any StorageProviding,
        onChange: @escaping (StorageProvidingEvent) -> Void
    ) {
        handle = provider.addObserver { event in
            onChange(event)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}

import MagicKit

/// 音频数据层的存储变化观察者。
///
/// 统一持有存储能力的订阅句柄，并在数据层生命周期结束时取消订阅。
/// 具体响应由使用方注入：插件入口用于重启文件同步，
/// `AudioLibraryProvider` 用于丢弃旧 Repository。
///
/// 事件载荷在能力边界被抹平：两个调用方都忽略原 `StorageProvidingEvent`
/// 的载荷，只把它当作「存储变了」的信号。
@MainActor
final class AudioStorageObserver: SuperLog {
    nonisolated static let emoji = "📦"
    nonisolated static let verbose = false

    private var handle: (any AudioDataStorageObserverHandle)?

    init(
        storage: any AudioDataStorageCapability,
        onChange: @escaping (AudioDataStorageEvent) -> Void
    ) {
        handle = storage.addObserver { event in
            onChange(event)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
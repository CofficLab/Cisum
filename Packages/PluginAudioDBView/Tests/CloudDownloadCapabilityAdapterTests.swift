import Foundation
import ProviderCloudDownload
import Testing
@testable import PluginAudioDBView

// MARK: - 测试替身

/// 记录订阅与取消动作的 Provider 替身。
@MainActor
final class StubCloudDownloadProvider: CloudDownloadProviding {
    private(set) var observerCount = 0
    private(set) var cancelledCount = 0
    private var callback: ((ProviderCloudDownload.CloudDownloadEvent) -> Void)?

    var progressValue: Double = 0.5

    func addObserver(
        _ callback: @escaping (ProviderCloudDownload.CloudDownloadEvent) -> Void
    ) -> any CloudDownloadProvidingObserverHandle {
        observerCount += 1
        self.callback = callback
        return StubCloudDownloadHandle { [weak self] in
            self?.cancelledCount += 1
            self?.callback = nil
        }
    }

    func progress(for url: URL) -> Double {
        progressValue
    }

    /// 主动推送一条进度事件。
    func emit(_ event: ProviderCloudDownload.CloudDownloadEvent) {
        callback?(event)
    }
}

@MainActor
final class StubCloudDownloadHandle: CloudDownloadProvidingObserverHandle {
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}

// MARK: - 能力适配器

/// 能力适配器是「插件消费内核 Provider」的唯一入口。
///
/// 这里要锁定的核心语义：
/// 1. **惰性解析**——Provider 注册晚于视图贡献时，能力不能永久失效；
/// 2. **降级语义**——Provider 缺失时 `progress(for:)` 必须返回「已完成」
///    （`1`），否则列表会永远显示一个转不动的进度环；
/// 3. **事件收窄**——只透出列表关心的 `progressChanged`。
@Suite("下载进度能力适配器")
@MainActor
struct CloudDownloadCapabilityAdapterTests {
    @Test("Provider 缺失时进度视为已完成")
    func missingProviderReportsCompletedProgress() {
        let adapter = CloudDownloadCapabilityAdapter(resolve: { nil })
        let url = URL(fileURLWithPath: "/tmp/song.mp3")

        // 1 表示「不在下载中」：否则列表会永远显示一个 0% 的进度环。
        #expect(adapter.progress(for: url) == 1)
    }

    @Test("Provider 缺失时订阅返回可安全取消的句柄")
    func missingProviderReturnsCancellableHandle() {
        let adapter = CloudDownloadCapabilityAdapter(resolve: { nil })

        let handle = adapter.addObserver { _ in }
        // 重复取消不应崩溃。
        handle.cancel()
        handle.cancel()
    }

    @Test("Provider 缺失时订阅不会调用回调")
    func missingProviderNeverNotifies() {
        let adapter = CloudDownloadCapabilityAdapter(resolve: { nil })
        var notified = false

        let handle = adapter.addObserver { _ in notified = true }
        handle.cancel()

        #expect(notified == false)
    }

    @Test("Provider 就绪时透出真实进度")
    func readyProviderReportsProgress() {
        let provider = StubCloudDownloadProvider()
        provider.progressValue = 0.25

        let adapter = CloudDownloadCapabilityAdapter(resolve: { provider })
        #expect(adapter.progress(for: URL(fileURLWithPath: "/tmp/song.mp3")) == 0.25)
    }

    @Test("Provider 后注册时能力自动生效")
    func lateProviderBecomesUsable() {
        var provider: StubCloudDownloadProvider?
        let adapter = CloudDownloadCapabilityAdapter(resolve: { provider })

        // 注册前：降级为「已完成」。
        #expect(adapter.progress(for: URL(fileURLWithPath: "/tmp/song.mp3")) == 1)

        // Provider 稍后注册（插件 boot 顺序不固定）。
        let late = StubCloudDownloadProvider()
        late.progressValue = 0.75
        provider = late

        // 每次调用都重新解析，因此能力自动恢复。
        #expect(adapter.progress(for: URL(fileURLWithPath: "/tmp/song.mp3")) == 0.75)
    }

    @Test("进度事件被透传给订阅者")
    func forwardsProgressEvents() {
        let provider = StubCloudDownloadProvider()
        let adapter = CloudDownloadCapabilityAdapter(resolve: { provider })

        var received: [(URL, Double)] = []
        let handle = adapter.addObserver { event in
            if case let .progressChanged(url, progress) = event {
                received.append((url, progress))
            }
        }

        let url = URL(fileURLWithPath: "/tmp/downloading.mp3")
        provider.emit(.progressChanged(url: url, progress: 0.42))

        #expect(received.count == 1)
        #expect(received.first?.0 == url)
        #expect(received.first?.1 == 0.42)

        handle.cancel()
    }

    @Test("取消订阅后不再收到事件")
    func cancelStopsForwarding() {
        let provider = StubCloudDownloadProvider()
        let adapter = CloudDownloadCapabilityAdapter(resolve: { provider })

        var received = 0
        let handle = adapter.addObserver { _ in received += 1 }

        provider.emit(.progressChanged(url: URL(fileURLWithPath: "/tmp/a.mp3"), progress: 0.1))
        #expect(received == 1)

        handle.cancel()
        provider.emit(.progressChanged(url: URL(fileURLWithPath: "/tmp/b.mp3"), progress: 0.2))
        #expect(received == 1)
    }

    @Test("订阅会真正注册到 Provider 上")
    func subscriptionReachesProvider() {
        let provider = StubCloudDownloadProvider()
        let adapter = CloudDownloadCapabilityAdapter(resolve: { provider })

        let handle = adapter.addObserver { _ in }
        #expect(provider.observerCount == 1)

        handle.cancel()
        #expect(provider.cancelledCount == 1)
    }
}

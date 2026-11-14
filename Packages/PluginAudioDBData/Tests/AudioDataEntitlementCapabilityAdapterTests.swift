import Foundation
import ProviderStore
import Testing
@testable import PluginAudioDBData

// MARK: - 测试替身

/// 可控的商店权益 Provider 替身。
@MainActor
final class StubStoreEntitlementProvider: StoreEntitlementProviding {
    /// 权益快照是唯一真值；`tier` 由共享契约的默认实现派生。
    var entitlement: StoreEntitlementSnapshot

    private(set) var observerCount = 0
    private(set) var cancelledCount = 0
    private var callback: ((StoreEntitlementEvent) -> Void)?

    init(tier: StoreTier = .none) {
        self.entitlement = StoreEntitlementSnapshot(
            tier: tier,
            expiresAt: tier > .none ? Date().addingTimeInterval(3600) : nil
        )
    }

    func addObserver(
        _ callback: @escaping (StoreEntitlementEvent) -> Void
    ) -> any StoreEntitlementObserverHandle {
        observerCount += 1
        self.callback = callback
        return StubStoreEntitlementHandle { [weak self] in
            self?.cancelledCount += 1
            self?.callback = nil
        }
    }

    /// 模拟用户完成购买：等级变化并派发事件。
    func simulateUpgrade(to tier: StoreTier) {
        self.entitlement = StoreEntitlementSnapshot(
            tier: tier,
            expiresAt: tier > .none ? Date().addingTimeInterval(3600) : nil
        )
        callback?(.tierChanged(tier))
    }
}

@MainActor
final class StubStoreEntitlementHandle: StoreEntitlementObserverHandle {
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}

// MARK: - 权益能力适配器

/// 权益适配器把「订阅等级」翻译成数据层唯一关心的结论：「受不受容量限制」。
///
/// 关键语义：
/// 1. **Provider 未就绪 → 按受限处理**——宁可先挡住，也不要让免费用户
///    在商店 Provider 尚未注册时绕过上限；
/// 2. **惰性解析**——Provider 晚注册时能力自动生效；
/// 3. **观察句柄可取消**——取消后不再收到事件。
@Suite("订阅权益能力适配器")
@MainActor
struct AudioDataEntitlementCapabilityAdapterTests {
    @Test("Provider 未就绪时按受限处理")
    func missingProviderIsCapacityLimited() {
        let adapter = AudioDataEntitlementCapabilityAdapter(resolve: { nil })

        // 未就绪时必须「受限」：否则免费用户可以绕过上限。
        #expect(adapter.isCapacityLimited)
    }

    @Test("Provider 未就绪时显示免费档")
    func missingProviderShowsFreeTier() {
        let adapter = AudioDataEntitlementCapabilityAdapter(resolve: { nil })
        #expect(adapter.tierDisplayName == StoreTier.none.defaultDisplayName)
    }

    @Test("免费用户受容量限制")
    func freeUserIsLimited() {
        let provider = StubStoreEntitlementProvider(tier: .none)
        let adapter = AudioDataEntitlementCapabilityAdapter(resolve: { provider })

        #expect(adapter.isCapacityLimited)
        #expect(adapter.tierDisplayName == StoreTier.none.defaultDisplayName)
    }

    @Test("专业版用户不受容量限制")
    func proUserIsUnlimited() {
        let provider = StubStoreEntitlementProvider(tier: .pro)
        let adapter = AudioDataEntitlementCapabilityAdapter(resolve: { provider })

        #expect(adapter.isCapacityLimited == false)
        #expect(adapter.tierDisplayName == StoreTier.pro.defaultDisplayName)
    }

    @Test("旗舰版用户不受容量限制")
    func ultimateUserIsUnlimited() {
        let provider = StubStoreEntitlementProvider(tier: .ultimate)
        let adapter = AudioDataEntitlementCapabilityAdapter(resolve: { provider })

        #expect(adapter.isCapacityLimited == false)
        #expect(adapter.tierDisplayName == StoreTier.ultimate.defaultDisplayName)
    }

    @Test("Provider 晚注册后容量判定自动修正")
    func lateProviderCorrectsLimitation() {
        var provider: StubStoreEntitlementProvider?
        let adapter = AudioDataEntitlementCapabilityAdapter(resolve: { provider })

        // 注册前：受限。
        #expect(adapter.isCapacityLimited)

        // 商店插件稍后完成 boot。
        provider = StubStoreEntitlementProvider(tier: .pro)

        // 每次读取都重新解析，因此判定自动修正为「不受限」。
        #expect(adapter.isCapacityLimited == false)
    }

    @Test("Provider 就绪时订阅会被真正注册")
    func subscriptionReachesProvider() {
        let provider = StubStoreEntitlementProvider(tier: .pro)
        let adapter = AudioDataEntitlementCapabilityAdapter(resolve: { provider })

        let handle = adapter.addObserver { _ in }
        #expect(provider.observerCount == 1)

        handle.cancel()
    }

    @Test("Provider 实例更换后重新订阅")
    func resubscribesWhenProviderInstanceChanges() async throws {
        // 插件管理页可停用 / 启用商店插件：停用会注销 Provider，
        // 启用会注册**新的实例**。适配器必须重新订阅，否则权益变化事件
        // 会静默丢失（用户升级后容量上限仍按免费档计算）。
        var provider: StubStoreEntitlementProvider? = StubStoreEntitlementProvider(tier: .none)
        let adapter = AudioDataEntitlementCapabilityAdapter(resolve: { provider })

        var changedCount = 0
        let handle = adapter.addObserver { _ in changedCount += 1 }
        #expect(provider?.observerCount == 1)

        // 商店插件重启：换成一个全新实例。
        let restarted = StubStoreEntitlementProvider(tier: .pro)
        provider = restarted

        // 适配器会复查 Provider 实例并重新订阅。
        try await Self.waitUntil { restarted.observerCount == 1 }
        #expect(restarted.observerCount == 1)

        // 新实例上的事件必须能被收到。
        restarted.simulateUpgrade(to: .ultimate)
        #expect(changedCount == 1)

        handle.cancel()
    }

    @Test("Provider 实例更换时旧实例被退订")
    func oldSubscriptionIsCancelledOnProviderSwap() async throws {
        var provider: StubStoreEntitlementProvider? = StubStoreEntitlementProvider(tier: .none)
        let adapter = AudioDataEntitlementCapabilityAdapter(resolve: { provider })

        let original = provider!
        let handle = adapter.addObserver { _ in }

        let restarted = StubStoreEntitlementProvider(tier: .pro)
        provider = restarted

        // 触发一次重新解析（新增订阅者）。
        let second = adapter.addObserver { _ in }

        // 旧实例的订阅必须已被取消，避免继续收到已注销实例的事件。
        #expect(original.cancelledCount == 1)
        #expect(restarted.observerCount == 1)

        handle.cancel()
        second.cancel()
    }

    @Test("Provider 未就绪时稍后注册能自动补上订阅")
    func subscribesWhenProviderAppearsLater() async throws {
        var provider: StubStoreEntitlementProvider?
        let adapter = AudioDataEntitlementCapabilityAdapter(resolve: { provider })

        var changedCount = 0
        let handle = adapter.addObserver { _ in changedCount += 1 }

        // Provider 尚未注册：不应崩溃，也不应建立订阅。
        #expect(provider == nil)

        // Provider 稍后注册（商店插件 boot 顺序不固定）。
        let late = StubStoreEntitlementProvider(tier: .pro)
        provider = late

        try await Self.waitUntil { late.observerCount == 1 }
        #expect(late.observerCount == 1)

        late.simulateUpgrade(to: .ultimate)
        #expect(changedCount == 1)

        handle.cancel()
    }

    /// 等待条件成立（最多约 2 秒）。
    private static func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        Issue.record("等待条件在 \(timeout)s 内未成立")
    }

    @Test("同一个 Provider 实例不会被重复订阅")
    func doesNotResubscribeToSameInstance() {
        let provider = StubStoreEntitlementProvider(tier: .pro)
        let adapter = AudioDataEntitlementCapabilityAdapter(resolve: { provider })

        let first = adapter.addObserver { _ in }
        let second = adapter.addObserver { _ in }

        // 同一实例只订阅一次，避免重复派发。
        #expect(provider.observerCount == 1)

        first.cancel()
        second.cancel()
    }

    @Test("权益变化事件被转发给订阅者")
    func forwardsEntitlementChange() {
        let provider = StubStoreEntitlementProvider(tier: .none)
        let adapter = AudioDataEntitlementCapabilityAdapter(resolve: { provider })

        var changedCount = 0
        let handle = adapter.addObserver { event in
            if case .changed = event {
                changedCount += 1
            }
        }

        provider.simulateUpgrade(to: .pro)
        #expect(changedCount == 1)

        // 升级后容量判定也应随之变化。
        #expect(adapter.isCapacityLimited == false)

        handle.cancel()
    }

    @Test("取消订阅后不再收到事件")
    func cancelStopsForwarding() {
        let provider = StubStoreEntitlementProvider(tier: .none)
        let adapter = AudioDataEntitlementCapabilityAdapter(resolve: { provider })

        var changedCount = 0
        let handle = adapter.addObserver { _ in changedCount += 1 }

        provider.simulateUpgrade(to: .pro)
        #expect(changedCount == 1)

        handle.cancel()
        provider.simulateUpgrade(to: .ultimate)
        #expect(changedCount == 1)
    }

    @Test("重复取消订阅是安全的")
    func repeatedCancelIsSafe() {
        let provider = StubStoreEntitlementProvider(tier: .pro)
        let adapter = AudioDataEntitlementCapabilityAdapter(resolve: { provider })

        let handle = adapter.addObserver { _ in }
        handle.cancel()
        handle.cancel()
    }

    @Test("Provider 未就绪时订阅不会崩溃")
    func missingProviderSubscriptionIsSafe() {
        let adapter = AudioDataEntitlementCapabilityAdapter(resolve: { nil })

        var notified = false
        let handle = adapter.addObserver { _ in notified = true }
        handle.cancel()

        #expect(notified == false)
    }

    @Test("多个订阅者各自独立")
    func multipleObserversAreIndependent() {
        let provider = StubStoreEntitlementProvider(tier: .none)
        let adapter = AudioDataEntitlementCapabilityAdapter(resolve: { provider })

        var firstCount = 0
        var secondCount = 0
        let first = adapter.addObserver { _ in firstCount += 1 }
        let second = adapter.addObserver { _ in secondCount += 1 }

        provider.simulateUpgrade(to: .pro)
        #expect(firstCount == 1)
        #expect(secondCount == 1)

        // 取消其中一个，另一个继续接收。
        first.cancel()
        provider.simulateUpgrade(to: .ultimate)
        #expect(firstCount == 1)
        #expect(secondCount == 2)

        second.cancel()
    }
}

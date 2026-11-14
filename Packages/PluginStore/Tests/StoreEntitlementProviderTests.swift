import Foundation
import ProviderStore
import ProviderStoreKit
import SwiftUI
import Testing
@testable import PluginStore

// MARK: - 权益 Provider

/// 权益 Provider 直接读取快照，不缓存副本。
///
/// 权益会被 StoreKit 在任意时刻改写（购买、过期、恢复、退款）；缓存一份
/// 副本等于让「过期了但仍按 Pro 放行」变成常态。
@MainActor
@Test func entitlementProviderReadsSnapshotOnEveryAccess() {
    var snapshot = StoreEntitlementSnapshot(tier: .none, expiresAt: nil)
    let provider = StoreEntitlementProvider(readEntitlement: { snapshot })

    #expect(provider.tier == .none)

    snapshot = StoreEntitlementSnapshot(
        tier: .pro,
        expiresAt: Date().addingTimeInterval(3600)
    )
    #expect(provider.tier == .pro)

    snapshot = StoreEntitlementSnapshot(tier: .none, expiresAt: nil)
    #expect(provider.tier == .none)
}

/// 过期快照派生的档位是免费档。
@MainActor
@Test func entitlementProviderTreatsExpiredSnapshotAsFree() {
    let provider = StoreEntitlementProvider(
        readEntitlement: {
            StoreEntitlementSnapshot(
                tier: .pro,
                expiresAt: Date().addingTimeInterval(-3600)
            )
        }
    )

    #expect(provider.tier == .none)
    #expect(provider.entitlement.isExpired)
}

/// 交易更新时派发等级变化事件。
@MainActor
@Test func entitlementProviderPublishesTierChangeOnTransactionUpdate() async throws {
    var snapshot = StoreEntitlementSnapshot(tier: .none, expiresAt: nil)
    let provider = StoreEntitlementProvider(readEntitlement: { snapshot })

    var received: [StoreTier] = []
    let handle = provider.addObserver { event in
        if case .tierChanged(let newTier) = event {
            received.append(newTier)
        }
    }
    defer { handle.cancel() }

    // 等级变化 + 交易通知 → 派发一次。
    snapshot = StoreEntitlementSnapshot(
        tier: .pro,
        expiresAt: Date().addingTimeInterval(3600)
    )
    NotificationCenter.default.post(name: .storeTransactionUpdated, object: "com.yueyi.cisum.pro.monthly")
    try await Task.sleep(for: .milliseconds(50))

    #expect(received == [.pro])

    // 等级没变 → 不重复派发。
    NotificationCenter.default.post(name: .storeTransactionUpdated, object: "com.yueyi.cisum.pro.monthly")
    try await Task.sleep(for: .milliseconds(50))

    #expect(received == [.pro])
}

/// 取消观察后不再收到事件。
@MainActor
@Test func entitlementProviderStopsPublishingAfterCancel() async throws {
    var snapshot = StoreEntitlementSnapshot(tier: .none, expiresAt: nil)
    let provider = StoreEntitlementProvider(readEntitlement: { snapshot })

    var received: [StoreTier] = []
    let handle = provider.addObserver { event in
        if case .tierChanged(let newTier) = event {
            received.append(newTier)
        }
    }
    handle.cancel()

    snapshot = StoreEntitlementSnapshot(
        tier: .pro,
        expiresAt: Date().addingTimeInterval(3600)
    )
    NotificationCenter.default.post(name: .storeTransactionUpdated, object: "com.yueyi.cisum.pro.monthly")
    try await Task.sleep(for: .milliseconds(50))

    #expect(received.isEmpty)
}

/// 构造时权益已经是 Pro：不应因为「第一次读到 Pro」就派发一次变化。
@MainActor
@Test func entitlementProviderDoesNotPublishInitialTierAsChange() async throws {
    let provider = StoreEntitlementProvider(
        readEntitlement: {
            StoreEntitlementSnapshot(
                tier: .pro,
                expiresAt: Date().addingTimeInterval(3600)
            )
        }
    )

    var received: [StoreTier] = []
    let handle = provider.addObserver { event in
        if case .tierChanged(let newTier) = event {
            received.append(newTier)
        }
    }
    defer { handle.cancel() }

    NotificationCenter.default.post(name: .storeTransactionUpdated, object: "com.yueyi.cisum.pro.monthly")
    try await Task.sleep(for: .milliseconds(50))

    #expect(received.isEmpty)
}

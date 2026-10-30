import Foundation
import ProviderStore
import SwiftUI
import Testing
@testable import PluginStore

// MARK: - 权益 Provider

/// 权益 Provider 直接读取等级，不缓存副本。
///
/// 权益会被 StoreKit 在任意时刻改写（购买、过期、恢复、退款）；缓存一份
/// 副本等于让「过期了但仍按 Pro 放行」变成常态。
@MainActor
@Test func entitlementProviderReadsTierOnEveryAccess() {
    var tier: SubscriptionTier = .none
    let provider = StoreEntitlementProvider(readTier: { tier })

    #expect(provider.tier == .none)

    tier = .pro
    #expect(provider.tier == .pro)

    tier = .none
    #expect(provider.tier == .none)
}

/// 交易更新时派发等级变化事件。
@MainActor
@Test func entitlementProviderPublishesTierChangeOnTransactionUpdate() async throws {
    var tier: SubscriptionTier = .none
    let provider = StoreEntitlementProvider(readTier: { tier })

    var received: [SubscriptionTier] = []
    let handle = provider.addObserver { event in
        if case .tierChanged(let newTier) = event {
            received.append(newTier)
        }
    }
    defer { handle.cancel() }

    // 等级变化 + 交易通知 → 派发一次。
    tier = .pro
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
    var tier: SubscriptionTier = .none
    let provider = StoreEntitlementProvider(readTier: { tier })

    var received: [SubscriptionTier] = []
    let handle = provider.addObserver { event in
        if case .tierChanged(let newTier) = event {
            received.append(newTier)
        }
    }
    handle.cancel()

    tier = .pro
    NotificationCenter.default.post(name: .storeTransactionUpdated, object: "com.yueyi.cisum.pro.monthly")
    try await Task.sleep(for: .milliseconds(50))

    #expect(received.isEmpty)
}

/// 构造时权益已经是 Pro：不应因为「第一次读到 Pro」就派发一次变化。
@MainActor
@Test func entitlementProviderDoesNotPublishInitialTierAsChange() async throws {
    let provider = StoreEntitlementProvider(readTier: { .pro })

    var received: [SubscriptionTier] = []
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

// MARK: - 购买面板呈现

/// 呈现请求会让购买面板进入可见状态。
@MainActor
@Test func purchasePresentationOpensOnRequest() {
    let presentation = StorePurchasePresentation()
    #expect(presentation.isPresented == false)

    presentation.present()
    #expect(presentation.isPresented == true)

    presentation.dismiss()
    #expect(presentation.isPresented == false)
}

/// 重复呈现不会叠加多个面板（同一个状态机驱动）。
@MainActor
@Test func purchasePresentationIsIdempotent() {
    let presentation = StorePurchasePresentation()

    presentation.present()
    presentation.present()
    presentation.present()

    #expect(presentation.isPresented == true)
}

/// Provider 把呈现请求转发到状态机。
@MainActor
@Test func purchasePresentingProviderForwardsToPresentation() {
    let presentation = StorePurchasePresentation()
    let provider = StorePurchasePresentingProvider(presentation: presentation)

    #expect(presentation.isPresented == false)
    provider.presentPurchase()
    #expect(presentation.isPresented == true)
}

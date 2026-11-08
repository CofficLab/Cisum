import Foundation
import Testing
@testable import KitStoreKit

/// 权益持久化与配置注入的测试。
@Suite("StoreKitEntitlementStorage")
struct StoreKitEntitlementStorageTests {

    /// 内存态存储替身：避免单元测试读写真实 `UserDefaults` 而互相污染。
    private final class InMemoryEntitlementStorage: StoreKitEntitlementStoring, @unchecked Sendable {
        private var expiration: Date?
        private var lastCheckedAt: Date?

        func loadExpiration() -> Date? { expiration }
        func saveExpiration(_ date: Date) { expiration = date }
        func clearExpiration() { expiration = nil }
        func loadLastCheckedAt() -> Date? { lastCheckedAt }
        func saveLastCheckedAt(_ date: Date) { lastCheckedAt = date }
    }

    /// 到期时间写入后能读回。
    @Test func expirationRoundTripsThroughStorage() {
        let storage = InMemoryEntitlementStorage()
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        storage.saveExpiration(date)

        #expect(storage.loadExpiration() == date)
    }

    /// 清除后读回 `nil`。
    @Test func clearingRemovesStoredExpiration() {
        let storage = InMemoryEntitlementStorage()
        storage.saveExpiration(Date(timeIntervalSince1970: 1_800_000_000))

        storage.clearExpiration()

        #expect(storage.loadExpiration() == nil)
    }

    /// 校准时间能写入并读回。
    @Test func lastCheckedAtRoundTrips() {
        let storage = InMemoryEntitlementStorage()
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        storage.saveLastCheckedAt(date)

        #expect(storage.loadLastCheckedAt() == date)
    }

    /// `UserDefaults` 实现：未写入时读到 `nil`（而非 0 值日期）。
    ///
    /// `UserDefaults.double(forKey:)` 对缺失 key 返回 0，若直接当时间戳用会
    /// 得到 1970 年这个看似合法实则荒谬的日期。
    @Test func userDefaultsStorageReturnsNilWhenNeverWritten() {
        let defaults = UserDefaults(suiteName: "LumiStoreKitTests.\(UUID().uuidString)")!
        let storage = UserDefaultsStoreKitEntitlementStorage(
            defaults: defaults,
            entitlementKey: "test.expiration",
            lastCheckedAtKey: "test.lastCheckedAt"
        )

        #expect(storage.loadExpiration() == nil)
        #expect(storage.loadLastCheckedAt() == nil)
    }

    /// `UserDefaults` 实现：写入后能读回。
    @Test func userDefaultsStorageRoundTrips() {
        let defaults = UserDefaults(suiteName: "LumiStoreKitTests.\(UUID().uuidString)")!
        let storage = UserDefaultsStoreKitEntitlementStorage(
            defaults: defaults,
            entitlementKey: "test.expiration",
            lastCheckedAtKey: "test.lastCheckedAt"
        )
        let expiration = Date(timeIntervalSince1970: 1_800_000_000)
        let checkedAt = Date(timeIntervalSince1970: 1_800_000_100)

        storage.saveExpiration(expiration)
        storage.saveLastCheckedAt(checkedAt)

        #expect(storage.loadExpiration() == expiration)
        #expect(storage.loadLastCheckedAt() == checkedAt)
    }
}

/// 配置注入点的测试。
@Suite("StoreKitConfiguration")
struct StoreKitConfigurationTests {

    /// 配置保留注入的商品清单与 key。
    @Test func configurationKeepsInjectedValues() {
        let configuration = StoreKitConfiguration(
            productIDs: ["com.example.pro.monthly", "com.example.pro.yearly"],
            entitlementStorageKey: "custom.purchase",
            lastCheckedAtStorageKey: "custom.lastCheckedAt"
        )

        #expect(configuration.productIDs.count == 2)
        #expect(configuration.entitlementStorageKey == "custom.purchase")
        #expect(configuration.lastCheckedAtStorageKey == "custom.lastCheckedAt")
    }

    /// 默认 key 保持向后兼容。
    @Test func configurationUsesDefaultKeys() {
        let configuration = StoreKitConfiguration(productIDs: [])

        #expect(configuration.entitlementStorageKey == "store.purchase")
        #expect(configuration.lastCheckedAtStorageKey == "store.lastCheckedAt")
    }

    /// 商品清单为空时不报错（供尚未配置商品的 App 使用）。
    @Test func emptyProductListIsAllowed() {
        let configuration = StoreKitConfiguration(productIDs: [])

        #expect(configuration.productIDs.isEmpty)
    }
}

import CisumProviderStorage
import Foundation
@testable import PluginStorage
import ProviderStorage
import Testing

/// 首启存储引导依赖的 storage gate 契约。
///
/// `WelcomeStorageSetupOverlay` 只在 `hasUsableStorageLocation == false` 时显示，
/// 因此这条断言链就是"引导何时出现 / 何时消失"的唯一数据源：
///
/// - 新用户（无已保存位置）→ gate 关闭 → 引导必须显示；
/// - 用户点「继续」提交（`setStorageLocation`）→ gate 打开 → 引导关闭；
/// - 提交的值不可用（如 iCloud 未登录）→ gate 保持关闭，引导不得假关闭，
///   否则用户会进入一个存储位置无效的主界面。
@MainActor
@Test func onboardingGateOpensOnlyAfterStorageChoiceIsCommitted() {
    let suiteName = "OnboardingStorageGateTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let provider = StorageProvider(userDefaults: defaults)

    // 新用户首启：没有任何已保存位置 → 引导必须显示。
    #expect(provider.currentStorageLocation == nil)
    #expect(!provider.hasUsableStorageLocation)

    // 用户点「继续」提交本地存储 → 引导应关闭。
    provider.setStorageLocation(.local)
    #expect(provider.hasUsableStorageLocation)
    #expect(provider.currentStorageLocation == .local)

    // 重置回新用户状态 → 引导重新出现。
    provider.resetStorageLocation()
    #expect(provider.currentStorageLocation == nil)
    #expect(!provider.hasUsableStorageLocation)
}

@MainActor
@Test func committingUnavailableICloudKeepsOnboardingGateClosed() {
    let suiteName = "OnboardingStorageGateICloudTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let provider = StorageProvider(userDefaults: defaults)

    // 本机 iCloud 可用时该场景由 UI 层正常提交，这里只验证不可用分支。
    guard !provider.isICloudStorageAvailable else { return }

    provider.setStorageLocation(.icloud)

    #expect(
        !provider.hasUsableStorageLocation,
        "iCloud 不可用时提交 iCloud 不应解除引导：否则主界面会拿到一个无效的存储位置"
    )
}

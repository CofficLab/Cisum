import CisumProviderStorage
import Foundation
import Testing
@testable import PluginWelcome

// MARK: - 存储能力 Adapter 的退化契约

/// 存储 Provider 未就绪时，能力必须退化为「无可用存储」，
/// 而不是崩溃或误报可用 —— 引导页据此决定是否展示存储选择层。
@MainActor
@Test func storageCapabilityReportsUnavailableWithoutProvider() {
    let capability = WelcomeStorageCapabilityAdapter(storage: nil)
    #expect(capability.hasUsableStorageLocation == false)
}

/// Provider 缺席时订阅也应安全返回句柄，取消不应崩溃。
/// 若此处抛空或强解包，首启（Provider 尚未注册）会直接崩在引导页。
@MainActor
@Test func storageCapabilityObserverIsSafeWithoutProvider() {
    let capability = WelcomeStorageCapabilityAdapter(storage: nil)

    var notified = false
    let handle = capability.addObserver { _ in notified = true }

    #expect(!notified) // 无 Provider 时不应触发回调
    handle.cancel()
    handle.cancel() // 幂等：重复取消无副作用
}

// MARK: - 根视图外观能力 Adapter 的退化契约

/// 根视图 Provider 未就绪时，隐藏工具栏不应崩溃 ——
/// 引导层可能在 RootViewProvider 注册前就展示。
@MainActor
@Test func rootChromeCapabilityIsSafeWithoutProvider() {
    let capability = WelcomeRootChromeCapabilityAdapter(root: nil)

    // 不崩溃即为通过
    capability.setToolbarHidden(true)
    capability.setToolbarHidden(false)
}

@MainActor
@Test func rootChromeObserverIsSafeWithoutProvider() {
    let capability = WelcomeRootChromeCapabilityAdapter(root: nil)

    var notified = false
    let handle = capability.addObserver { _ in notified = true }

    #expect(!notified)
    handle.cancel()
    handle.cancel() // 幂等
}

// MARK: - 存储选择枚举

@Test func storageSelectionRawValuesAreStable() {
    // rawValue 会写入 UserDefaults，改动会导致既有用户配置失效
    #expect(WelcomeStorageSelection.icloud.rawValue == "icloud")
    #expect(WelcomeStorageSelection.local.rawValue == "local")
    #expect(WelcomeStorageSelection(rawValue: "icloud") == .icloud)
    #expect(WelcomeStorageSelection(rawValue: "local") == .local)
    #expect(WelcomeStorageSelection(rawValue: "unknown") == nil)
}

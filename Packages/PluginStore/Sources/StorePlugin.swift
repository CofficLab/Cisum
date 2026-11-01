import ProviderDocsView
import ProviderRootView
import LumiUI
import KernelCore
import ProviderPlugin
import KitAppEvents
import ProviderSettingView
import SwiftUI
import MagicKit
import OSLog
import ProviderStore
import ProviderStoreKit

@MainActor
public final class StorePlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: StorePlugin.self)

    nonisolated static let verbose = false

    nonisolated static let logger = Logger(subsystem: "com.coffic.cisum", category: "plugin.store")

    public static let shared = StorePlugin()
    public let order = 80
    public let iconName = StorePluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: StorePlugin.self),
        name: String(localized: String.LocalizationValue(StorePluginInfo.titleKey), bundle: .module),
        version: "1.0.0",
        category: .system,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) private var storeViewModel: StoreViewModel?
    nonisolated(unsafe) private var storeObserver: StoreObserver?

    /// 订阅权益 Provider：本插件是商店能力的唯一生产者，
    /// 消费方（如仓库容量规则）经内核解析 `StoreEntitlementProviding` 获取。
    nonisolated(unsafe) private var entitlementProvider: StoreEntitlementProvider?

    /// 购买面板呈现状态机：全局 overlay 与设置页共用同一份购买内容。
    nonisolated(unsafe) private var purchasePresentation: StorePurchasePresentation?

    /// 购买面板呈现 Provider：撞限引导等「请商店弹购买面板」的触发点经内核解析它。
    nonisolated(unsafe) private var purchasePresentingProvider: StorePurchasePresentingProvider?

    /// 根视图 overlay 的标识，卸载时按此移除。
    private static let purchaseOverlayID = "cisum.store.purchase-overlay"

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { StorePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { StorePluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        StoreService.bootstrap()
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let entry = makeSettingEntry() { kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([entry]) }
        }
        installState()
        installEntitlementProvider(kernel: kernel)
        installPurchasePresenting(kernel: kernel)
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: ["store"])
        kernel.resolveProvider((any RootViewProviding).self)?.removeOverlays(ids: [Self.purchaseOverlayID])
        kernel.unregisterProvider((any StoreEntitlementProviding).self)
        kernel.unregisterProvider((any StorePurchasePresenting).self)
        entitlementProvider?.shutdown()
        entitlementProvider = nil
        purchasePresentingProvider = nil
        purchasePresentation = nil
        teardownState()
    }

    @MainActor
    public func makeSettingEntry() -> SettingEntryItem? {
        let viewModel = resolveViewModel()
        return SettingEntryItem(
            id: "store",
            title: String(localized: String.LocalizationValue(StorePluginInfo.titleKey), bundle: .module),
            systemImage: iconName,
            order: 80,
            detail: {
            StoreSetting(viewModel: viewModel)
        }
        )
    }

    // MARK: - State assembly

    /// 注册订阅权益 Provider（幂等）。
    ///
    /// 本插件是商店能力的唯一生产者：仓库容量规则等消费方经内核解析
    /// `StoreEntitlementProviding` 拿到「当前是不是免费用户」这一个结论，
    /// 不需要知道 StoreKit 的存在。
    @MainActor
    private func installEntitlementProvider(kernel: KernelCoreContainer) {
        guard entitlementProvider == nil else { return }
        let provider = StoreEntitlementProvider()
        do {
            try kernel.registerProvider((any StoreEntitlementProviding).self, provider)
            entitlementProvider = provider
        } catch {
            Self.logger.error("\(Self.t)Failed to register StoreEntitlementProviding: \(error.localizedDescription)")
        }
    }

    /// 注册购买面板呈现 Provider（幂等）并把 overlay 装到根视图。
    ///
    /// 撞限的免费用户需要一条「点一下就能付费」的通路。触发点在各个插件里
    /// （仓库视图、拖放导入），但购买界面只此一份：这里把它挂成根视图
    /// overlay，触发点经内核解析 `StorePurchasePresenting` 请求呈现即可。
    @MainActor
    private func installPurchasePresenting(kernel: KernelCoreContainer) {
        guard purchasePresentingProvider == nil else { return }

        let presentation = StorePurchasePresentation()
        let provider = StorePurchasePresentingProvider(presentation: presentation)
        do {
            try kernel.registerProvider((any StorePurchasePresenting).self, provider)
        } catch {
            Self.logger.error("\(Self.t)Failed to register StorePurchasePresenting: \(error.localizedDescription)")
            return
        }

        purchasePresentation = presentation
        purchasePresentingProvider = provider

        guard let root = kernel.resolveProvider((any RootViewProviding).self) else { return }
        root.addOverlays([
            RootOverlayItem(id: Self.purchaseOverlayID, order: 9_500) { content in
                // 内容必须作为主体层传入：写成 `.overlay(content)` 会让
                // 整个应用根视图变成「空视图的覆盖层」，主窗口就什么都不剩。
                StorePurchaseOverlay(presentation: presentation) {
                    content
                }
            }
        ])
    }

    @MainActor
    private func installState() {
        guard storeViewModel == nil else { return }
        let viewModel = StoreViewModel()
        let observer = StoreObserver(viewModel: viewModel)
        storeViewModel = viewModel
        storeObserver = observer
    }

    @MainActor
    private func teardownState() {
        storeObserver?.cancel()
        storeObserver = nil
        storeViewModel = nil
    }

    @MainActor
    private func resolveViewModel() -> StoreViewModel {
        if let storeViewModel {
            return storeViewModel
        }
        let viewModel = StoreViewModel()
        storeViewModel = viewModel
        return viewModel
    }
}

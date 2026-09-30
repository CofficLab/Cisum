import ProviderDocsView
import CisumUIComponents
import LumiUI
import KernelCore
import ProviderPlugin
import KitAppEvents
import ProviderSettingView
import SwiftUI
import MagicKit

/// 设置 - 通用 插件（复刻 Lumi `PluginSettingGeneral`）。
///
/// 在设置窗口注册「通用」导航入口（gearshape，order 1 排最前），详情展示
/// 应用信息与说明书浏览器。说明书浏览器读取内核 `DocsViewProviding`
/// 贡献的 manual 条目。
@MainActor
public final class SettingGeneralPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: SettingGeneralPlugin.self)

    nonisolated static let verbose = false

    public static let shared = SettingGeneralPlugin()
    public let order = 1
    public let iconName = "gearshape"
    public let metadata = PluginMetadata(
        id: String(describing: SettingGeneralPlugin.self),
        name: String(localized: "General Settings", bundle: .module),
        version: "1.0.0",
        category: .core,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { SettingGeneralPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { SettingGeneralPluginManualView() })
        }
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: ["general"])
    }

    /// onBoot 时保存的内核引用，用于构造说明书浏览器的数据源。
    nonisolated(unsafe) private var kernel: KernelCoreContainer?

    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let view = self.addSettingView() { contrib.addSettingView(ownerPluginID: id, view) }
            if let entry = makeSettingEntry() { kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([entry]) }
        }
        self.kernel = kernel
    }

    @MainActor
    public func addSettingView() -> AnyView? {
        nil
    }

    @MainActor
    public func makeSettingEntry() -> SettingEntryItem? {
        SettingEntryItem(
            id: "general",
            title: String(localized: "General", bundle: .module),
            systemImage: iconName,
            order: order,
            detail: {
            GeneralSettingsDetailView(
                            viewModel: GeneralSettingsViewModel(
                                manualEntries: self.kernel?.resolveProvider((any DocsViewProviding).self)?.manualEntries ?? []
                            )
                        )
        }
        )
    }
}
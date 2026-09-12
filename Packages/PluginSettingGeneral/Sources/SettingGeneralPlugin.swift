import CisumUIComponents
import KernelCore
import ProviderDocsView
import SwiftUI
import MagicKit

/// 设置 - 通用 插件（复刻 Lumi `PluginSettingGeneral`）。
///
/// 在设置窗口注册「通用」导航入口（gearshape，order 1 排最前），详情展示
/// 应用信息与说明书浏览器。说明书浏览器读取内核 `DocsViewProviding`
/// 贡献的 manual 条目。
public actor SettingGeneralPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = SettingGeneralPlugin()
    public static let metadata = PluginMetadata(
        displayName: String(localized: "General Settings", bundle: .module),
        description: String(localized: "Provides general settings such as app info and manuals in the Settings window.", bundle: .module),
        iconName: "gearshape",
        order: 1,
        policy: .alwaysOn,
        category: .core,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { SettingGeneralPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { SettingGeneralPluginManualView() })
        }
    }

    /// onBoot 时保存的内核引用，用于构造说明书浏览器的数据源。
    nonisolated(unsafe) private var kernel: CisumKernel?

    public func onBoot(kernel: CisumKernel) async throws {
        self.kernel = kernel
    }

    @MainActor
    public func addSettingView() -> AnyView? {
        nil
    }

    @MainActor
    public func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        PluginSettingNavigationItem(
            id: "general",
            title: String(localized: "General", bundle: .module),
            description: Self.metadata.description,
            iconName: Self.metadata.iconName,
            order: Self.metadata.order,
            destination: AnyView(GeneralSettingsDetailView(
                viewModel: GeneralSettingsViewModel(
                    manualEntries: kernel?.docs?.manualEntries ?? []
                )
            ))
        )
    }
}

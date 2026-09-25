import ProviderDocsView
import ProviderTheme
import CisumUIComponents
import CisumKernelSupport
import SwiftUI
import MagicKit

/// 主题设置插件（对齐 Lumi `ThemePackPlugin` 的设置入口范式）。
///
/// Lumi 的 `ThemePackPlugin` 在设置窗口注册独立的「外观」（paintpalette，
/// order 2）入口，详情页列出全部主题供切换——Cisum 复刻该入口：
/// - macOS：贡献 `appearance` 导航项，右侧为主题管理详情页；
/// - iOS：设置窗口为简化版（导航项不可交互），主题设置保留在「插件设置」
///   聚合页中，避免入口丢失。
///
/// 入口在 `onBoot` 创建并持有长期存在的 `ThemeSettingsViewModel` 与
/// `ThemeProvidingObserver`，设置导航项注入同一个 ViewModel；View 不自行创建
/// 状态对象。
@MainActor
public final class ThemeSettingsPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: ThemeSettingsPlugin.self)

    nonisolated static let verbose = false

    public static let shared = ThemeSettingsPlugin()
    public let order = ThemeSettingsPluginInfo.order
    public let iconName = ThemeSettingsPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: ThemeSettingsPlugin.self),
        name: ThemeSettingsPluginInfo.title,
        description: ThemeSettingsPluginInfo.description,
        version: "1.0.0",
        category: .system,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) private var settingsViewModel: ThemeSettingsViewModel?
    nonisolated(unsafe) private var settingsObserver: ThemeProvidingObserver?

    public init() {}

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { ThemeSettingsPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { ThemeSettingsPluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let view = self.addSettingNavigationItem() { contrib.addSettingNavigationItem(view) }
        }
        installSettingsState(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        installSettingsState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        teardownSettingsState()
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        teardownSettingsState()
    }

    @MainActor
    public func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        // View 贡献可能在插件启动前被请求：保证返回一个稳定、长期存在的
        // ViewModel，而不是每次请求都重新创建。
        let viewModel = settingsViewModel ?? {
            let viewModel = ThemeSettingsViewModel(capability: nil)
            settingsViewModel = viewModel
            return viewModel
        }()
        return PluginSettingNavigationItem(
            id: "appearance",
            title: String(localized: "Appearance", bundle: .module),
            description: metadata.description,
            iconName: "paintpalette",
            order: 2,
            destination: AnyView(ThemeSettingsDetailView(viewModel: viewModel))
        )
    }

    // MARK: - Settings state assembly

    @MainActor
    private func installSettingsState(kernel: KernelCoreContainer) {
        guard settingsViewModel == nil else { return }
        guard let theme = kernel.resolveProvider((any ThemeProviding).self) else { return }
        let viewModel = ThemeSettingsViewModel(
            capability: ThemeSettingsCapabilityAdapter(theme: theme)
        )
        let observer = ThemeProvidingObserver(provider: theme, viewModel: viewModel)
        settingsViewModel = viewModel
        settingsObserver = observer
    }

    @MainActor
    private func teardownSettingsState() {
        settingsObserver?.cancel()
        settingsObserver = nil
        settingsViewModel = nil
    }
}
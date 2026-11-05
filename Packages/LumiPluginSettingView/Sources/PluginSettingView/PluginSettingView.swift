import KernelCore
import ProviderSettingView

/// Replaces the default settings provider with Lumi's plugin-owned settings view.
@MainActor
public final class PluginSettingView: SuperPlugin {
    /// 默认插件标识。宿主可在装配时传入自己的 id。
    public static let defaultPluginID = "com.coffic.kuzee.plugin.setting-view"

    public let id: String
    public let order = 3
    public let metadata: PluginMetadata

    private var manager: SettingViewManager?

    /// 创建设置窗口插件。
    ///
    /// - Parameter id: 插件唯一标识，决定 `PluginMetadata.id`。
    public init(id: String = PluginSettingView.defaultPluginID) {
        self.id = id
        self.metadata = PluginMetadata(
            id: id,
            name: "设置窗口",
            description: "提供设置窗口的外壳与侧边栏入口渲染。",
            category: .core,
            policy: .required
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        let manager = SettingViewManager()
        self.manager = manager

        // Preserve entries and selection contributed before this provider plugin boots.
        if let old = kernel.resolveProvider((any SettingViewProviding).self) {
            manager.registerEntries(old.entries)
            manager.selectEntry(id: old.selectedEntryID)
        }

        kernel.unregisterProvider((any SettingViewProviding).self)
        try kernel.registerProvider((any SettingViewProviding).self, manager)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        manager = nil
    }
}

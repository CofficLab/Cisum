import KernelCore
import LumiLoggingKit
import ProviderSettingView
import SwiftUI
import os

/// 「关于」插件。
///
/// 在宿主设置界面注入一个独立入口「关于」，页面包含两部分：
/// - **我们的应用**：Coffic Lab 旗下其他应用，链接到官网的对应产品页；
/// - **关于我们**：宿主自己的官网、隐私政策、服务条款，以及无障碍与 AI 使用说明。
///
/// 宿主可注入自己的品牌 id 与官网地址复用本包（与 `PluginPluginManager` /
/// `PluginStorage` 的做法一致）。
@MainActor
public final class AboutPlugin: SuperPlugin, SuperLog {
    /// 默认插件标识。宿主可在装配时传入自己的 id。
    public static let defaultPluginID = "com.coffic.lumi.plugin.about"

    /// 插件唯一标识。宿主可注入自己的品牌 id。
    public let id: String

    /// 插件加载顺序。排在通用设置之后，避免抢在宿主自己的核心入口前面。
    public let order = 95

    /// 插件元信息。
    public let metadata: PluginMetadata

    /// 日志子系统跟随插件 id，便于宿主在系统日志中区分品牌。
    nonisolated let logger: Logger

    /// 设置入口的稳定 ID。恒为固定值（与品牌无关），供设置深链使用。
    public static let settingsEntryID = "about"

    /// 页面配置：宿主自己的官网与法律链接。
    public let configuration: AboutConfiguration

    /// 插件自身的启用策略。
    ///
    /// 默认 `.alwaysOn`：「关于」页是应用的身份页，宿主几乎总是需要它。
    /// 宿主若不希望它出现，可传 `.disabled` —— 内核启动时会彻底排除这个
    /// 插件，入口也随之消失。
    public let policy: PluginEnablePolicy

    /// 创建「关于」插件。
    ///
    /// - Parameters:
    ///   - id: 插件唯一标识，决定 `PluginMetadata.id` 与日志子系统。
    ///   - configuration: 宿主配置（官网与法律链接）。
    ///   - policy: 插件自身的启用策略。
    public init(
        id: String = AboutPlugin.defaultPluginID,
        configuration: AboutConfiguration,
        policy: PluginEnablePolicy = .alwaysOn
    ) {
        self.id = id
        self.configuration = configuration
        self.policy = policy
        self.metadata = PluginMetadata(
            id: id,
            name: pluginLocalization.string("About"),
            description: pluginLocalization.string("Our apps and information about this app."),
            version: "2.0.0",
            category: .general,
            stage: .stable,
            policy: policy
        )
        self.logger = Logger(subsystem: id, category: "About")
    }

    // MARK: - Lifecycle

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            logger.error("\(Self.t) SettingViewProviding not found, settings entry skipped")
            return
        }

        let entry = SettingEntryItem(
            id: Self.settingsEntryID,
            title: pluginLocalization.string("About"),
            systemImage: "info.circle",
            order: 95
        ) {
            AboutView(configuration: self.configuration)
        }
        settings.addEntries([entry])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: [Self.settingsEntryID])
    }
}

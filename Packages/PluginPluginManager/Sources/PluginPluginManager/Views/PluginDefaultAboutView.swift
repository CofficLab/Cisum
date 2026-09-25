import CisumUIComponents
import CisumKernel
import SwiftUI

/// 所有插件的默认关于页（对齐 Lumi `PluginPluginManager.PluginDefaultAboutView`）。
///
/// 插件可以贡献自己的品牌化 AboutView；没有贡献时，由插件管理器使用这
/// 个页面保证仍然提供完整、可读的插件说明。
struct PluginDefaultAboutView: View {
    @LumiTheme private var theme

    let metadata: PluginMetadata
    let isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LandingHero(
                icon: metadata.category.systemImage,
                accent: theme.primary,
                tagline: metadata.description.isEmpty ? "No Description Available" : metadata.description,
                chips: [metadata.category.displayName, metadata.stage.displayName],
                metrics: [
                    .init(value: metadata.version, label: String(localized: "Version", bundle: .module)),
                    .init(value: policyValue, label: String(localized: "Strategy", bundle: .module))
                ]
            )

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "info.circle") {
                LandingFeatureGrid(items: [
                    .init(
                        icon: metadata.category.systemImage,
                        tint: theme.primary,
                        title: String(localized: "Category", bundle: .module),
                        description: metadata.category.displayName
                    ),
                    .init(
                        icon: "checkmark.seal",
                        tint: theme.success,
                        title: String(localized: "Stage", bundle: .module),
                        description: metadata.stage.displayName
                    ),
                    .init(
                        icon: "lock.shield",
                        tint: theme.warning,
                        title: String(localized: "Strategy", bundle: .module),
                        description: policyValue
                    ),
                    .init(
                        icon: "number.circle",
                        tint: theme.info,
                        title: String(localized: "Identifier", bundle: .module),
                        description: metadata.id.isEmpty ? "Not Set" : metadata.id
                    )
                ], minColumnWidth: 180)
            }

            if !metadata.permissions.isEmpty {
                LandingSection(title: String(localized: "Permissions", bundle: .module), icon: "hand.raised") {
                    LandingInventory(
                        tint: theme.warning,
                        items: metadata.permissions.map {
                            .init(icon: "checkmark.shield", title: "\($0.id): \($0.reason)")
                        }
                    )
                }
            }
        }
    }

    private var policyValue: String {
        switch metadata.policy {
        case .alwaysOn:
            String(localized: "Always Enabled", bundle: .module)
        case .disabled:
            String(localized: "Disable Permanently", bundle: .module)
        case .optOut, .optIn:
            isEnabled ? "Enabled" : "Disabled"
        }
    }
}

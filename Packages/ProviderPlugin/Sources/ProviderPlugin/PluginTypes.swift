import SwiftUI

/// 设置导航项（Cisum 应用特有模型，对齐 Lumi `SettingEntryItem` 语义）。
public struct PluginSettingNavigationItem: Identifiable {
    public let id: String
    public let title: String
    public let description: String?
    public let iconName: String
    public let order: Int
    public let destination: AnyView

    public init(
        id: String,
        title: String,
        description: String? = nil,
        iconName: String,
        order: Int,
        destination: AnyView
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.iconName = iconName
        self.order = order
        self.destination = destination
    }
}

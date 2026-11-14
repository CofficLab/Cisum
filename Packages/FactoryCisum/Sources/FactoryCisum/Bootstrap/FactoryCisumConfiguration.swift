import Foundation

/// 宿主在编译期确定的内核组装配置。
///
/// 对齐 Lumi 的 `FactoryConfiguration`。Cisum 的插件清单由
/// `FactoryCisum.DefaultPluginFactory` 直接装配（不再经宿主/Registry 注入），
/// 因此配置无需携带插件列表；此处保留为空配置结构，便于未来扩展
/// （如默认启停集合、窗口尺寸等）。
public struct FactoryCisumConfiguration: Sendable {
    public init() {}
}

import Foundation
import ProviderDocsView

/// 插件管理页所需的文档能力。
///
/// 内核 `DocsViewProviding` 还包含贡献 about/manual 条目的写入能力，
/// 管理页是被动消费方：只按插件 id 读取已贡献的条目，故在此收窄。
@MainActor
protocol PluginManagerDocsCapability: AnyObject {
    /// 指定插件贡献的 about 条目；未贡献时为 `nil`。
    func aboutEntry(id: String) -> DocsEntry?
}

/// 将内核 `DocsViewProviding` 收窄为插件管理页的文档能力。
@MainActor
final class PluginManagerDocsCapabilityAdapter: PluginManagerDocsCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「无文档条目」而非延长其生命周期。
    private weak var docs: (any DocsViewProviding)?

    init(docs: (any DocsViewProviding)?) {
        self.docs = docs
    }

    func aboutEntry(id: String) -> DocsEntry? {
        docs?.aboutEntries.first { $0.id == id }
    }

}
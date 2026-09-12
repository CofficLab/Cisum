import Foundation
import ProviderDocsView

/// 通用设置页的唯一数据来源。
///
/// 说明书条目由插件组装层从 `DocsViewProviding` 解析后注入；
/// View 只读取本 ViewModel，不直接接触 Provider。
@MainActor
final class GeneralSettingsViewModel: ObservableObject {
    /// 各插件贡献的说明书条目。
    @Published private(set) var manualEntries: [DocsEntry] = []

    init(manualEntries: [DocsEntry] = []) {
        self.manualEntries = manualEntries
    }
}

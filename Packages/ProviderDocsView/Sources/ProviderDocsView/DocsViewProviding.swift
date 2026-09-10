import Combine
import SwiftUI

// MARK: - Docs Entry

/// 文档条目（由插件注入，对齐 Lumi `DocsEntry`）。
///
/// 标识一个插件贡献的文档（关于 / 说明书）：
/// - `id`：插件唯一标识
/// - `name`：插件显示名（用于列表展示）
/// - `makeView`：文档视图
@MainActor
public struct DocsEntry: Identifiable {
    public let id: String
    public let name: String
    public let makeView: @MainActor () -> AnyView

    public init(
        id: String,
        name: String,
        @ViewBuilder makeView: @escaping @MainActor () -> some View
    ) {
        self.id = id
        self.name = name
        self.makeView = { AnyView(makeView()) }
    }
}

// MARK: - Docs View Providing

/// 文档视图提供能力协议（对齐 Lumi `DocsViewProviding`）。
///
/// 定义「内核 → 插件文档（关于 / 说明书）」这一段的最小契约：插件在
/// `onRegister` 中解析 `DocsViewProviding`，通过 `addAbout(_:)` /
/// `addManual(_:)` 注入自己的关于页与说明书条目；宿主在合适位置
/// （如设置 → 通用 → 说明书，以及插件管理详情）展示。
///
/// 采用追加语义（多插件各自贡献），`name` 用于说明书浏览器等列表形态的展示。
@MainActor
public protocol DocsViewProviding: AnyObject, ObservableObject
    where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 全部「关于」条目。
    var aboutEntries: [DocsEntry] { get }

    /// 全部「说明书」条目。
    var manualEntries: [DocsEntry] { get }

    /// 替换全部「关于」条目。
    func replaceAboutEntries(_ entries: [DocsEntry])

    /// 替换全部「说明书」条目。
    func replaceManualEntries(_ entries: [DocsEntry])

    /// 追加一个「关于」条目（同 id 去重，保留先注册者）。
    func addAbout(_ entry: DocsEntry)

    /// 追加一个「说明书」条目（同 id 去重，保留先注册者）。
    func addManual(_ entry: DocsEntry)

    /// 同时撤回指定插件的关于与说明书贡献。
    func removeEntries(id: String)
}

public extension DocsViewProviding {
    /// 追加语义的默认实现：合入已有条目（同 id 去重）。
    func addAbout(_ entry: DocsEntry) {
        var merged = aboutEntries
        if !merged.contains(where: { $0.id == entry.id }) {
            merged.append(entry)
        }
        replaceAboutEntries(merged)
    }

    /// 追加语义的默认实现：合入已有条目（同 id 去重）。
    func addManual(_ entry: DocsEntry) {
        var merged = manualEntries
        if !merged.contains(where: { $0.id == entry.id }) {
            merged.append(entry)
        }
        replaceManualEntries(merged)
    }

    func removeEntries(id: String) {
        replaceAboutEntries(aboutEntries.filter { $0.id != id })
        replaceManualEntries(manualEntries.filter { $0.id != id })
    }
}

// MARK: - Default Implementation

/// `DocsViewProviding` 的默认实现：持有「关于」与「说明书」条目数组。
///
/// 插件通过 `addAbout(_:)` / `addManual(_:)` 追加自己的文档条目；
/// 支持多插件各自贡献（与 `DefaultSettingViewProviding` 追加语义一致）。
@MainActor
public final class DefaultDocsViewProvider: DocsViewProviding, ObservableObject {
    @Published public private(set) var aboutEntries: [DocsEntry] = []
    @Published public private(set) var manualEntries: [DocsEntry] = []

    public init() {}

    public func replaceAboutEntries(_ entries: [DocsEntry]) {
        aboutEntries = entries
    }

    public func replaceManualEntries(_ entries: [DocsEntry]) {
        manualEntries = entries
    }
}

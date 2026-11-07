import Foundation

/// Coffic Lab 旗下的一款应用，或一个相关网站。
///
/// 名称与简介都走本地化 key，由视图层按当前系统语言解析：
/// 多数品牌名在各语言下拼写一致，未收录时解析结果就是 key 本身；
/// 有中文名的条目（如网站「快易知」）在字符串目录里提供对应译文。
public struct CofficApp: Identifiable, Sendable, Equatable {
    /// 条目类型：应用与网站虽然复用同一套行样式，但在页面上分组展示。
    public enum Kind: String, Sendable, Hashable {
        /// 旗下应用。
        case app
        /// 相关网站（不是可安装的 App）。
        case website
    }

    /// 稳定标识，用于列表 `id` 与测试断言。
    public let id: String

    /// 名称对应的本地化 key（如 `Lumi`、`Kuzee`）。
    public let nameKey: String

    /// 一句话简介对应的本地化 key。
    public let taglineKey: String

    /// 行首图标（SF Symbol 名称）。
    public let systemImage: String

    /// 官网短地址（应用为 `https://coffic.cn/<slug>`，网站为站点首页）。
    public let urlString: String

    /// 条目类型。默认按应用处理，网站条目需显式声明。
    public let kind: Kind

    public init(
        id: String,
        nameKey: String,
        taglineKey: String,
        systemImage: String,
        urlString: String,
        kind: Kind = .app
    ) {
        self.id = id
        self.nameKey = nameKey
        self.taglineKey = taglineKey
        self.systemImage = systemImage
        self.urlString = urlString
        self.kind = kind
    }
}

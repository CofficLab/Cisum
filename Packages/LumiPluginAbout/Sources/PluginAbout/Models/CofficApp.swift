import Foundation

/// Coffic Lab 旗下的一款应用。
///
/// 品牌名在各语言下拼写一致，因此直接以字面量书写；只有面向用户的简介
/// 走本地化 key，避免出现「不可本地化的用户可见文本」。
public struct CofficApp: Identifiable, Sendable, Equatable {
    /// 稳定标识，用于列表 `id` 与测试断言。
    public let id: String

    /// 品牌名（如 `Lumi`）。
    public let name: String

    /// 一句话简介对应的本地化 key。
    public let taglineKey: String

    /// 行首图标（SF Symbol 名称）。
    public let systemImage: String

    /// 官网短地址（`https://coffic.cn/<slug>`）。
    public let urlString: String

    public init(
        id: String,
        name: String,
        taglineKey: String,
        systemImage: String,
        urlString: String
    ) {
        self.id = id
        self.name = name
        self.taglineKey = taglineKey
        self.systemImage = systemImage
        self.urlString = urlString
    }
}

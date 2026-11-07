import Foundation

/// 「关于」页的宿主配置。
///
/// 「关于」页分两部分：
/// - **我们的一部分**：Coffic Lab 旗下其他应用（对所有宿主一致）；
/// - **关于本应用**：宿主自己的官网、隐私政策、服务条款（各家不同）。
///
/// 后者必须由宿主注入 —— 官网地址是宿主自己的产品页，插件无从推断。
public struct AboutConfiguration: Sendable, Equatable {
    /// 宿主官网（产品介绍页）的完整地址。
    ///
    /// 例：`https://coffic.cn/cisum`。
    public let officialWebsiteURLString: String

    /// 隐私政策地址。缺省时「关于我们」分组不展示该行。
    public let privacyPolicyURLString: String?

    /// 服务条款地址。缺省时「关于我们」分组不展示该行。
    public let termsOfServiceURLString: String?

    public init(
        officialWebsiteURLString: String,
        privacyPolicyURLString: String? = nil,
        termsOfServiceURLString: String? = nil
    ) {
        self.officialWebsiteURLString = officialWebsiteURLString
        self.privacyPolicyURLString = privacyPolicyURLString
        self.termsOfServiceURLString = termsOfServiceURLString
    }
}

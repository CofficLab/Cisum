import LumiUI
import SwiftUI

/// 「关于」页详情视图。
///
/// 两个分组：
/// - **我们的应用**：Coffic Lab 旗下其他应用，每行一款，链接到官网产品页；
/// - **关于我们**：宿主自己的官网、隐私政策、服务条款。
///
/// 行一律作为 `AppSettingSection` 的直接子元素（不套 `VStack`）：
/// - macOS：section 内部是 `VStack(spacing: 12)`，行间自动留白；
/// - iOS：section 内部是 `VStack(spacing: 0)`，靠 `AppSettingRow`
///   自带的发丝分隔线区分行（再画一条会变成双线）。
public struct AboutView: View {
    /// 应用列表（展示顺序即列表顺序）。
    private let apps: [CofficApp]

    /// 宿主配置（官网与法律链接）。
    private let configuration: AboutConfiguration

    /// 「全部产品」入口地址。
    private let allProductsURLString: String

    // MARK: - 文案

    private var ourAppsTitle: String { pluginLocalization.string("Our Apps") }
    private var allProductsTitle: String { pluginLocalization.string("All Products") }
    private var allProductsDescription: String { pluginLocalization.string("Browse the full product catalog on the web.") }
    private var aboutUsTitle: String { pluginLocalization.string("About Us") }
    private var officialWebsiteTitle: String { pluginLocalization.string("Official Website") }
    private var privacyPolicyTitle: String { pluginLocalization.string("Privacy Policy") }
    private var termsOfServiceTitle: String { pluginLocalization.string("Terms of Service") }

    @Environment(\.openURL) private var openURL

    public init(
        configuration: AboutConfiguration,
        apps: [CofficApp] = CofficApps.all,
        allProductsURLString: String = CofficApps.allProductsURLString
    ) {
        self.configuration = configuration
        self.apps = apps
        self.allProductsURLString = allProductsURLString
    }

    public var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 16) {
                ourAppsSection
                aboutUsSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Sections

    /// 「我们的应用」分组。
    private var ourAppsSection: some View {
        AppSettingSection(title: ourAppsTitle) {
            ForEach(apps) { app in
                linkRow(
                    title: app.name,
                    description: pluginLocalization.string(app.taglineKey),
                    systemImage: app.systemImage,
                    urlString: app.urlString
                )
            }

            linkRow(
                title: allProductsTitle,
                description: allProductsDescription,
                systemImage: "square.grid.2x2",
                urlString: allProductsURLString
            )
        }
    }

    /// 「关于我们」分组：宿主自己的官网与法律链接。
    private var aboutUsSection: some View {
        AppSettingSection(title: aboutUsTitle) {
            linkRow(
                title: officialWebsiteTitle,
                description: hostDescription(for: configuration.officialWebsiteURLString),
                systemImage: "globe",
                urlString: configuration.officialWebsiteURLString
            )

            if let privacyURL = configuration.privacyPolicyURLString {
                linkRow(
                    title: privacyPolicyTitle,
                    description: hostDescription(for: privacyURL),
                    systemImage: "hand.raised",
                    urlString: privacyURL
                )
            }

            if let termsURL = configuration.termsOfServiceURLString {
                linkRow(
                    title: termsOfServiceTitle,
                    description: hostDescription(for: termsURL),
                    systemImage: "doc.text",
                    urlString: termsURL
                )
            }
        }
    }

    // MARK: - Rows

    /// 通用链接行：图标 + 标题 / 说明 + 跳转箭头。
    private func linkRow(
        title: String,
        description: String,
        systemImage: String,
        urlString: String
    ) -> some View {
        AppSettingRow(
            title: title,
            description: description,
            icon: systemImage,
            action: { open(urlString) }
        ) {
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

    /// 行内展示的地址文本：去掉 `https://` 前缀，让用户一眼看清域名与路径。
    private func hostDescription(for urlString: String) -> String {
        urlString.replacingOccurrences(of: "https://", with: "")
    }

    /// 在默认浏览器中打开链接。
    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        openURL(url)
    }
}

#Preview {
    AboutView(
        configuration: AboutConfiguration(
            officialWebsiteURLString: "https://coffic.cn/cisum",
            privacyPolicyURLString: "https://coffic.cn/privacy",
            termsOfServiceURLString: "https://coffic.cn/terms"
        )
    )
    .padding()
    .frame(width: 460)
}

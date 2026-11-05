import LumiUI
import SwiftUI

/// 商店底部的法律链接：隐私政策与许可协议。
///
/// 购买弹层与设置页都要展示这组链接，因此抽成独立组件：链接地址与文案
/// 只有这一份，不会出现「弹层里改了、设置页没改」的漂移。
///
/// 内嵌在设置页时不再自带滚动容器，由外层（`AppSettingsContentScaffold`）
/// 统一滚动。
struct StoreLegalLinks: View {
    /// 链接横向排列。
    var showsDivider: Bool = true

    /// 隐私政策地址。
    static var privacyURL: URL? {
        URL(string: "https://coffic.cn/privacy")
    }

    /// 许可协议地址（Apple 标准 EULA）。
    static var licenseURL: URL? {
        URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    }

    var body: some View {
        if let privacyURL = Self.privacyURL,
           let licenseURL = Self.licenseURL {
            HStack(spacing: 20) {
                Link(destination: privacyURL) {
                    Label {
                        Text("Privacy Policy", bundle: .module)
                    } icon: {
                        Image(systemName: "hand.raised.fill")
                    }
                    .font(.footnote)
                }

                if showsDivider {
                    Divider()
                        .frame(height: 12)
                }

                Link(destination: licenseURL) {
                    Label {
                        Text("License Agreement", bundle: .module)
                    } icon: {
                        Image(systemName: "doc.text.fill")
                    }
                    .font(.footnote)
                }
            }
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
            .padding(.vertical, 16)
            .infiniteWidth()
        }
    }
}

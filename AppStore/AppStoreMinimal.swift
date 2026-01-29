import MagicKit
import SwiftUI

struct AppStoreMinimal: View {
    var body: some View {
        Group {
            Group {
                Text("极简设计")
                    .bold()
                    .font(.system(size: 100, design: .rounded))
                    .magicOceanGradient()
                    .padding(.bottom, 40)
                    .shadowSm()

                VStack(spacing: 16) {
                    FeatureItem(icon: .iconTrash, title: "没有广告", description: "纯净体验，专注音乐")
                    FeatureItem(icon: .iconPhoneCall, title: "不需要注册", description: "打开即用，快速上手")
                    FeatureItem(icon: .iconMinusCircle, title: "不需要登录", description: "保护隐私，无需账号")
                    FeatureItem(icon: .iconShowInFinder, title: "没有弹窗", description: "简洁界面，无干扰")
                }
                .padding(.vertical, 20)
                .shadowSm()
            }
            .inMagicVStackCenter()

            Spacer(minLength: 100)

            ContentView()
                .inRootView()
                .inDemoMode()
                .frame(width: Config.minWidth)
                .frame(height: 650)
                .roundedLarge()
                .shadowSm()
        }
        .magicCentered()
        .withBackgroundDecorations()
        .background(
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.3),
                    Color.pink.opacity(0.2),
                    Color.purple.opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Feature Item

private struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        )
    }
}

// MARK: - Preview

#Preview("App Store Minimal") {
    AppStoreMinimal()
        .inMagicContainer(.macBook13, scale: 1)
}

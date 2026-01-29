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
                    AppStoreFeatureItem.withGradient(
                        icon: .iconTrash,
                        title: "没有广告",
                        description: "纯净体验，专注音乐"
                    )
                    AppStoreFeatureItem.withGradient(
                        icon: .iconPhoneCall,
                        title: "不需要注册",
                        description: "打开即用，快速上手"
                    )
                    AppStoreFeatureItem.withGradient(
                        icon: .iconMinusCircle,
                        title: "不需要登录",
                        description: "保护隐私，无需账号"
                    )
                    AppStoreFeatureItem.withGradient(
                        icon: .iconShowInFinder,
                        title: "没有弹窗",
                        description: "简洁界面，无干扰"
                    )
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

// MARK: - Preview

#Preview("App Store Minimal") {
    AppStoreMinimal()
        .inMagicContainer(.macBook13, scale: 1)
}

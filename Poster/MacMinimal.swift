import MagicKit
import SwiftUI

struct AppStoreMinimal: View {
    var body: some View {
        Group {
            Group {
                Text("极简设计")
                    .asPosterTitle()

                VStack(spacing: 16) {
                    AppStoreFeatureItem(
                        icon: "trash",
                        title: "没有广告",
                        description: "纯净体验，专注音乐"
                    )
                    AppStoreFeatureItem(
                        icon: "phone.bubble",
                        title: "没有注册",
                        description: "打开即用，快速上手"
                    )
                    AppStoreFeatureItem(
                        icon: "xmark.circle",
                        title: "没有登录",
                        description: "保护隐私，无需账号"
                    )
                    AppStoreFeatureItem(
                        icon: .iconInfo,
                        title: "没有弹窗",
                        description: "简洁界面，无干扰"
                    )
                }
                .py4()
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
        .inPosterContainer()
    }
}

// MARK: - Preview

#Preview("App Store Minimal") {
    AppStoreMinimal()
        .inMagicContainer(.macBook13, scale: 0.5)
}

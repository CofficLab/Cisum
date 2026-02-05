import MagicKit
import SwiftUI

struct AppStoreICloud: View {
    var body: some View {
        Group {
            Group {
                Text("iCloud 云同步")
                    .asPosterTitle()

                VStack(spacing: 16) {
                    AppStoreFeatureItem(
                        icon: "icloud",
                        title: "云端同步",
                        description: "音乐库实时同步，随时随地访问"
                    )
                    AppStoreFeatureItem(
                        icon: "ipad.and.iphone",
                        title: "多设备同步",
                        description: "iPhone、iPad、Mac 数据无缝流转"
                    )
                    AppStoreFeatureItem(
                        icon: "shield",
                        title: "安全备份",
                        description: "自动备份到 iCloud，数据永不丢失"
                    )
                    AppStoreFeatureItem(
                        icon: "arrow.clockwise",
                        title: "自动同步",
                        description: "添加或修改后自动同步，无需手动操作"
                    )
                }
                .py4()
            }
            .inMagicVStackCenter()

            Spacer(minLength: 100)

            ContentView()
                .inRootView()
                .inDemoMode()
                .inDownloadingMode()
                .frame(width: Config.minWidth)
                .frame(height: 650)
                .roundedLarge()
                .shadowSm()
        }
        .inPosterContainer()
    }
}

// MARK: - Preview

#Preview("App Store iCloud") {
    AppStoreICloud()
        .inMagicContainer(.macBook13_50Percent, scale: 0.5)
}

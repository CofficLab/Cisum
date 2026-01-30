import MagicKit
import SwiftUI

struct AppStoreAlbumArt: View {
    var body: some View {
        Group {
            Group {
                Text("专辑封面")
                    .asPosterTitle()

                VStack(spacing: 16) {
                    AppStoreFeatureItem(
                        icon: .iconPhotosFill,
                        title: "高清封面",
                        description: "自动获取专辑封面，无需手动添加"
                    )
                }
                .py4()
            }
            .inMagicVStackCenter()

            Spacer(minLength: 100)

            ZStack {
                // 第二个 ContentView（背景）
                ContentLayout()
                    .showDetail()
                    .inRootView()
                    .inDemoMode()
                    .frame(width: Config.minWidth)
                    .frame(height: 650)
                    .roundedLarge()
                    .rotation3DEffect(
                        .degrees(-3),
                        axis: (x: 0, y: 0, z: 1),
                        anchor: .bottomLeading,
                        perspective: 1.0
                    )
                    .offset(x: -60, y: -20)
                    .shadowSm()

                // 第一个 ContentView（前景）
                ContentLayout()
                    .hideDetail()
                    .inRootView()
                    .inDemoMode()
                    .frame(width: Config.minWidth)
                    .frame(height: 650)
                    .background(.background.opacity(0.5))
                    .roundedLarge()
                    .shadowXl()
                    .rotation3DEffect(
                        .degrees(3),
                        axis: (x: 0, y: 0, z: 1),
                        anchor: .bottomLeading,
                        perspective: 1.0
                    )
                    .offset(x: 10, y: -20)
            }
        }
        .inPosterContainer()
    }
}

// MARK: - Preview

#Preview("App Store Album Art") {
    AppStoreAlbumArt()
        .inMagicContainer(.macBook13, scale: 0.5)
}

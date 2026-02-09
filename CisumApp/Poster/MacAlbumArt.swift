import MagicKit
import SwiftUI

struct AppStoreAlbumArt: View {
    var body: some View {
        GeometryReader { geo in
            HStack {
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
                    .frame(width: geo.size.width * 0.4)
                    .py4()
                }
                .frame(width: geo.size.width * 0.5)
                .inMagicVStackCenter()

                ZStack {
                    ContentLayout()
                        .showDetail()
                        .inRootView()
                        .inDemoMode()
                        .frame(width: max(Config.minWidth, geo.size.width * 0.15))
                        .frame(height: geo.size.height * 0.4)
                        .roundedLarge()
                        .rotation3DEffect(
                            .degrees(-3),
                            axis: (x: 0, y: 0, z: 1),
                            anchor: .bottomLeading,
                            perspective: 1.0
                        )
                        .offset(x: -60, y: -20)
                        .shadowSm()
                        .scaleEffect(2)

                    ContentLayout()
                        .hideDetail()
                        .inRootView()
                        .inDemoMode()
                        .frame(width: max(Config.minWidth, geo.size.width * 0.15))
                        .frame(height: geo.size.height * 0.4)
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
                        .scaleEffect(2)
                }
                .frame(width: geo.size.width * 0.5)
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

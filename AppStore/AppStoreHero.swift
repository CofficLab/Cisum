import MagicKit
import SwiftUI

struct AppStoreHero: View {
    var body: some View {
        Group {
            Group {
                Text("Cisum")
                    .asPosterTitle()

                Text("简单纯粹的音乐播放器")
                    .asPosterSubTitle()
            }
            .inMagicVStackCenter()

            Spacer(minLength: 100)

            ZStack {
                // 第二个（背景）
                ContentLayout()
                    .showDetail()
                    .inRootView()
                    .inDemoMode()
                    .frame(width: Config.minWidth)
                    .frame(height: 650)
                    .roundedLarge()
                    .rotation3DEffect(
                        .degrees(-8),
                        axis: (x: 0, y: 0, z: 1),
                        anchor: .bottomLeading,
                        perspective: 1.0
                    )
                    .offset(x: -60, y: -20)
                    .shadowSm()

                // 第一个（前景）
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
                        .degrees(8),
                        axis: (x: 0, y: 0, z: 1),
                        anchor: .bottomLeading,
                        perspective: 1.0
                    )
                    .offset(x: 10, y: -20)
            }
        }
        .magicCentered()
        .withPosterDecorations()
    }
}

// MARK: - Preview

#Preview("App Store Hero") {
    AppStoreHero()
        .inMagicContainer(.macBook13, scale: 0.5)
}

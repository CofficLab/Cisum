import MagicKit
import SwiftUI

struct iPhoneHero: View {
    var body: some View {
        Group {
            Group {
                Text("Cisum")
                    .asPosterTitle()

                Text("简单纯粹的音乐播放器")
                    .asPosterSubTitle(forMac: false)
            }
            .inMagicVStackCenter()

            ZStack {
                // 第二个（背景）
                ContentLayout()
                    .showDetail()
                    .inRootView()
                    .inDemoMode()
                    .frame(width: Config.minWidth)
                    .frame(height: 500)
                    .roundedLarge()
                    .shadowSm()
            }
        }
        .inMagicVStackCenter()
        .inPosterContainer()
    }
}

// MARK: - Preview

#Preview("App Store Hero") {
    iPhoneHero()
        .inMagicContainer(.iPhone, scale: 1)
}

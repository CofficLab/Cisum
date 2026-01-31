import MagicKit
import SwiftUI

struct iPhoneHero: View {
    var body: some View {
        Group {
            Group {
                Text("Cisum")
                    .asPosterTitleForIPhone()

                Text("简单纯粹的音乐播放器")
                    .asPosterSubTitleForIPhone()
            }
            .inMagicVStackCenter()

            ContentLayout()
                .showDetail()
                .inRootView()
                .inDemoMode()
                .frame(width: Config.minWidth + 100)
                .frame(height: 600)
                .roundedLarge()
                .shadowSm()
        }
        .inMagicVStackCenter()
        .inPosterContainer()
    }
}

// MARK: - Preview

#Preview("App Store Hero") {
    iPhoneHero()
        .inMagicContainer(CGSize(width: 621, height: 1344), scale: 1)
}

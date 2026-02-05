import MagicKit
import SwiftUI

struct iPhoneAlbumArt: View {
    var body: some View {
        Group {
            Group {
                Text("Cisum")
                    .asPosterTitleForIPhone()

                Text("自动获取专辑封面")
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

#Preview("App Store iOS") {
    iPhoneAlbumArt()
        .inMagicContainer(CGSize(width: 621, height: 1344), scale: 1)
}

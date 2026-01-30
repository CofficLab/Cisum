import MagicKit
import SwiftUI

struct iPhoneAlbumArt: View {
    var body: some View {
        Group {
            Group {
                Text("Cisum")
                    .asPosterTitle()

                Text("自动获取专辑封面")
                    .asPosterSubTitle(forMac: false)
            }
            .inMagicVStackCenter()

            ContentLayout()
                .showDetail()
                .inRootView()
                .inDemoMode()
                .frame(width: Config.minWidth)
                .frame(height: 500)
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
        .inMagicContainer(.iPhone, scale: 0.9)
}

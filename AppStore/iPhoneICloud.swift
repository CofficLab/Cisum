import MagicKit
import SwiftUI

struct iPhoneICloud: View {
    var body: some View {
        Group {
            Group {
                Text("Cisum")
                    .asPosterTitle()

                Text("完美支持 iCloud")
                    .asPosterSubTitle(forMac: false)
            }
            .inMagicVStackCenter()

            ContentLayout()
                .hideDetail()
                .inRootView()
                .inDemoMode()
                .inDownloadingMode()
                .frame(width: Config.minWidth)
                .frame(height: 600)
                .roundedLarge()
                .shadowSm()
                .offset(x: 0, y: 100)
        }
        .inMagicVStackCenter()
        .inPosterContainer()
    }
}

// MARK: - Preview

#Preview("App Store Hero") {
    iPhoneICloud()
        .inMagicContainer(.iPhone, scale: 1)
}

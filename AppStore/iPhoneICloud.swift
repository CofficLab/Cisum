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
                .frame(width: Config.minWidth, height: 600)
                .frame(height: 500, alignment: .top)
                .clipped()
                .roundedLarge()
                .shadowSm()

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

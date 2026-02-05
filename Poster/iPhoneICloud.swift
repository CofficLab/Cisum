import MagicKit
import SwiftUI

struct iPhoneICloud: View {
    var body: some View {
        Group {
            Group {
                Text("Cisum")
                    .asPosterTitleForIPhone()

                Text("完美支持 iCloud")
                    .asPosterSubTitleForIPhone()
            }
            .inMagicVStackCenter()

            ContentLayout()
                .hideDetail()
                .inRootView()
                .inDemoMode()
                .inDownloadingMode()
                .frame(width: Config.minWidth + 100, height: 600)
                .frame(height: 600, alignment: .top)
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
        .inMagicContainer(CGSize(width: 621, height: 1344), scale: 1)
}

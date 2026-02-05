import MagicKit
import SwiftUI

struct iPhoneICloud: View {
    var body: some View {
        GeometryReader { geo in
            VStack {
                Group {
                    Text("Cisum")
                        .asPosterTitleForIPhone()

                    Text("完美支持 iCloud")
                        .asPosterSubTitleForIPhone()
                }
                .inMagicVStackCenter()
                .frame(height: geo.size.height * 0.3)

                ContentLayout()
                    .hideDetail()
                    .inRootView()
                    .inDemoMode()
                    .inDownloadingMode()
                    .frame(width: Config.minWidth + 100)
                    .frame(height: geo.size.height * 0.3)
                    .clipped()
                    .roundedLarge()
                    .shadowSm()
                    .scaleEffect(2)
                    .frame(height: geo.size.height * 0.7)
            }.inMagicHStackCenter()
        }
        .inPosterContainer()
    }
}

// MARK: - Preview

#Preview("App Store iOS - iCloud - iPhone 5.5") {
    iPhoneICloud()
        .inMagicContainer(.iPhone55, scale: 0.45)
}

#Preview("App Store iOS - iCloud - iPhone 6.5") {
    iPhoneICloud()
        .inMagicContainer(.iPhone65, scale: 0.45)
}

#Preview("App Store iOS - iCloud - iPhone 6.9") {
    iPhoneICloud()
        .inMagicContainer(.iPhone69, scale: 0.45)
}

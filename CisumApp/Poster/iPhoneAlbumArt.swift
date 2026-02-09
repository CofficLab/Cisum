import MagicKit
import SwiftUI

struct iPhoneAlbumArt: View {
    var body: some View {
        GeometryReader { geo in
            VStack {
                Group {
                    Text("Cisum")
                        .asPosterTitleForIPhone()

                    Text("自动获取专辑封面")
                        .asPosterSubTitleForIPhone()
                }
                .inMagicVStackCenter()
                .frame(height: geo.size.height * 0.3)

                ContentLayout()
                    .showDetail()
                    .inRootView()
                    .inDemoMode()
                    .frame(width: Config.minWidth + 100)
                    .frame(height: geo.size.height * 0.3)
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

#Preview("App Store iOS - Album Art - iPhone 5.5") {
    iPhoneAlbumArt()
        .inMagicContainer(.iPhone55, scale: 0.45)
}

#Preview("App Store iOS - Album Art - iPhone 6.5") {
    iPhoneAlbumArt()
        .inMagicContainer(.iPhone65, scale: 0.45)
}

#Preview("App Store iOS - Album Art - iPhone 6.9") {
    iPhoneAlbumArt()
        .inMagicContainer(.iPhone69, scale: 0.45)
}

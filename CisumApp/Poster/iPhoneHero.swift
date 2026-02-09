import MagicKit
import SwiftUI

struct iPhoneHero: View {
    var body: some View {
        GeometryReader { geo in
            VStack {
                Group {
                    Text("Cisum")
                        .asPosterTitleForIPhone()

                    Text("简单纯粹的音乐播放器")
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

#Preview("App Store iOS - Hero - iPhone 5.5") {
    iPhoneHero()
        .inMagicContainer(.iPhone55, scale: 0.45)
}

#Preview("App Store iOS - Hero - iPhone 6.5") {
    iPhoneHero()
        .inMagicContainer(.iPhone65, scale: 0.45)
}

#Preview("App Store iOS - Hero - iPhone 6.9") {
    iPhoneHero()
        .inMagicContainer(.iPhone69, scale: 0.45)
}

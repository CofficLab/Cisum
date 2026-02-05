import MagicKit
import SwiftUI

struct iPhoneMac: View {
    var body: some View {
        GeometryReader { geo in
            VStack {
                Group {
                    Text("Cisum")
                        .asPosterTitleForIPhone()

                    Text("macOS 上也精彩")
                        .asPosterSubTitleForIPhone()
                }
                .inMagicVStackCenter()
                .frame(height: geo.size.height * 0.3)

                LogoView()
                    .background(Config.rootBackground)
                    .shadowSm()
                    .inIMacScreen()
                    .frame(height: geo.size.height * 0.7)
            }.inMagicHStackCenter()
        }
        .inPosterContainer()
    }
}

// MARK: - Preview

#Preview("App Store iOS - Mac - iPhone 5.5") {
    iPhoneMac()
        .inMagicContainer(.iPhone55, scale: 0.45)
}

#Preview("App Store iOS - Mac - iPhone 6.5") {
    iPhoneMac()
        .inMagicContainer(.iPhone65, scale: 0.45)
}

#Preview("App Store iOS - Mac - iPhone 6.9") {
    iPhoneMac()
        .inMagicContainer(.iPhone69, scale: 0.45)
}

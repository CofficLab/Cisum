import MagicKit
import SwiftUI

struct iPhoneMac: View {
    var body: some View {
        Group {
            Group {
                Text("Cisum")
                    .asPosterTitle()

                Text("macOS 上也精彩")
                    .asPosterSubTitle(forMac: false)
            }
            .inMagicVStackCenter()

            LogoView(size: .infinity)
                .background(Config.rootBackground)
                .shadowSm()
                .inIMacScreen()
                .frame(height: 500)
        }
        .inMagicVStackCenter()
        .inPosterContainer()
    }
}

// MARK: - Preview

#Preview("App Store iOS") {
    iPhoneMac()
        .inMagicContainer(.iPhone, scale: 0.9)
}

import MagicKit
import SwiftUI

struct iPhoneMac: View {
    var body: some View {
        Group {
            Group {
                Text("Cisum")
                    .asPosterTitleForIPhone()

                Text("macOS 上也精彩")
                    .asPosterSubTitleForIPhone()
            }
            .inMagicVStackCenter()

            LogoView()
                .background(Config.rootBackground)
                .shadowSm()
                .inIMacScreen()
                .frame(height: 600)
        }
        .inMagicVStackCenter()
        .inPosterContainer()
    }
}

// MARK: - Preview

#Preview("App Store iOS") {
    iPhoneMac()
        .inMagicContainer(CGSize(width: 621, height: 1344), scale: 1)
}

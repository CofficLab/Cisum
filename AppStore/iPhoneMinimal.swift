import MagicKit
import SwiftUI

struct iPhoneMinimal: View {
    var body: some View {
        Group {
            Group {
                Text("Cisum")
                    .asPosterTitle()

                Text("极简设计")
                    .asPosterSubTitle(forMac: false)
            }
            .inMagicVStackCenter()

            Spacer(minLength: 80)

            ZStack {
                ContentLayout()
                    .hideDetail()
                    .inRootView()
                    .inDemoMode()
                    .frame(width: Config.minWidth)
                    .frame(height: 500)
                    .roundedLarge()
                    .shadowSm()
            }
        }
        .inMagicVStackCenter()
        .inPosterContainer()
    }
}

// MARK: - Preview

#Preview("App Store iPhone Minimal") {
    iPhoneMinimal()
        .inMagicContainer(.iPhone, scale: 1)
}

import MagicKit
import SwiftUI

struct iPhoneMinimal: View {
    var body: some View {
        Group {
            Group {
                Text("Cisum")
                    .asPosterTitleForIPhone()

                Text("极简设计")
                    .asPosterSubTitleForIPhone()
            }
            .inMagicVStackCenter()

            ZStack {
                ContentLayout()
                    .hideDetail()
                    .inRootView()
                    .inDemoMode()
                    .frame(width: Config.minWidth + 100)
                    .frame(height: 600)
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
        .inMagicContainer(CGSize(width: 621, height: 1344), scale: 1)
}

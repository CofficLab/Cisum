import MagicKit
import SwiftUI

struct iPhoneMinimal: View {
    var body: some View {
        GeometryReader { geo in
            VStack {
                Group {
                    Text("Cisum")
                        .asPosterTitleForIPhone()

                    Text("极简设计")
                        .asPosterSubTitleForIPhone()
                }
                .inMagicVStackCenter()
                .frame(height: geo.size.height * 0.3)

                ZStack {
                    ContentLayout()
                        .hideDetail()
                        .inRootView()
                        .inDemoMode()
                        .frame(width: Config.minWidth + 100)
                        .frame(height: geo.size.height * 0.3)
                        .roundedLarge()
                        .shadowSm()
                        .scaleEffect(2)
                }
                .frame(height: geo.size.height * 0.7)
            }.inMagicHStackCenter()
        }
        .inPosterContainer()
    }
}

// MARK: - Preview

#Preview("App Store iOS - Minimal - iPhone 5.5") {
    iPhoneMinimal()
        .inMagicContainer(.iPhone55, scale: 0.45)
}

#Preview("App Store iOS - Minimal - iPhone 6.5") {
    iPhoneMinimal()
        .inMagicContainer(.iPhone65, scale: 0.45)
}

#Preview("App Store iOS - Minimal - iPhone 6.9") {
    iPhoneMinimal()
        .inMagicContainer(.iPhone69, scale: 0.45)
}

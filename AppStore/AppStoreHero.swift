import MagicKit
import SwiftUI

struct AppStoreHero: View {
    var body: some View {
        Group {
            Group {
                Text("Cisum")
                    .bold()
                    .font(.system(size: 100, design: .rounded))
                    .magicOceanGradient()
                    .padding(.bottom, 20)
                    .shadowSm()

                Text("纯净播放，简单纯粹")
                    .font(.system(size: 50, design: .rounded))
                    .foregroundColor(.secondary)
                    .shadowSm()
            }.inMagicVStackCenter()

            Spacer(minLength: 100)

            ContentView()
                .inRootView()
                .inDemoMode()
                .frame(width: Config.minWidth)
                .frame(height: 650)
                .roundedLarge()
                .shadowSm()
        }
        .magicCentered()
        .withBackgroundDecorations()
        .background(
            LinearGradient(
                colors: [
                    Color.green.opacity(0.4),
                    Color.teal.opacity(0.3),
                    Color.mint.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Preview

#Preview("App Store Hero") {
    AppStoreHero()
        .inMagicContainer(.macBook13, scale: 1)
}

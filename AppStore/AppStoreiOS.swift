import MagicKit
import SwiftUI

struct AppStoreiOS: View {
    var body: some View {
        Group {
            Group {
                Text("iOS 完美适配")
                    .asPosterTitle()
            }
            .inMagicVStackCenter()
            .offset(x: 60, y: -20)

            Spacer(minLength: 0)

            ZStack {
                // 第二个 ContentView（背景）
                LogoView(size: .infinity)
                    .background(Config.rootBackground)
                    .inIPadScreen()
                    .frame(width: Config.minWidth)
                    .frame(height: 650)
                    .roundedLarge()
                    .rotation3DEffect(
                        .degrees(-8),
                        axis: (x: 0, y: 0, z: 1),
                        anchor: .bottomLeading,
                        perspective: 1.0
                    )
                    .offset(x: -60, y: 0)
                    .shadowSm()

                // 第一个 ContentView（前景）
                LogoView(size: .infinity)
                    .background(Config.rootBackground)
                    .inIPhoneScreen()
                    .shadowXl()
                    .rotation3DEffect(
                        .degrees(4),
                        axis: (x: 0, y: 0, z: 1),
                        anchor: .bottomLeading,
                        perspective: 1.0
                    )
                    .offset(x: 80, y: -20)
                    .shadowSm()
            }
        }
        .inPosterContainer()
    }
}

// MARK: - Preview

#Preview("App Store iOS") {
    AppStoreiOS()
        .inMagicContainer(.macBook13, scale: 0.5)
}

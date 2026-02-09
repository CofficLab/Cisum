import MagicKit
import OSLog
import SwiftUI

struct LogoView: View {
    var rotationSpeed: Double = 0.0

    @State private var rotationAngle: Double = 0.0

    init(
        rotationSpeed: Double = 0.0
    ) {
        self.rotationSpeed = rotationSpeed
    }

    var body: some View {
        Image.makeCoffeeReelIcon(
            useDefaultBackground: false,
            handleRotation: 0
        )
        .infinite()
        .shadow3xl()
        .rotationEffect(.degrees(rotationAngle))
        .onAppear {
            if rotationSpeed > 0 {
                startRotation()
            }
        }
    }

    private func startRotation() {
        withAnimation(.linear(duration: 1.0 / rotationSpeed).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
}

#Preview("LogoView") {
    ScrollView {
        LogoView()
            .frame(width: 250, height: 250)

        LogoView()
            .background(.blue.opacity(0.2))
            .roundedFull()
            .frame(width: 250, height: 250)

        LogoView(rotationSpeed: 0.05)
            .background(.green.opacity(0.2))
            .roundedFull()
            .frame(width: 250, height: 250)
    }
    .frame(height: 800)
    .frame(width: 500)
}

#Preview("LogoView - Snapshot") {
    LogoView()
        .background(LinearGradient.green2teal)
        .inMagicContainer(.init(width: 1024, height: 1024), scale: 0.5)
}

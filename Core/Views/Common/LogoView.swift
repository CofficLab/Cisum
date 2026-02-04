import MagicKit
import OSLog
import SwiftUI

// MARK: - Types

extension LogoView {
    enum BackgroundShape {
        case none
        case circle
        case rectangle
        case roundedRectangle(cornerRadius: CGFloat)
        case capsule
    }
}

struct LogoView: View, SuperLog {
    nonisolated static let verbose = false
    nonisolated static let emoji = "🎨"

    var background: Color?
    var rotationSpeed: Double = 0.0
    var backgroundShape: BackgroundShape = .none

    @State private var rotationAngle: Double = 0.0

    init(
        background: Color? = nil,
        rotationSpeed: Double = 0.0,
        backgroundShape: BackgroundShape = .none
    ) {
        self.background = background
        self.rotationSpeed = rotationSpeed
        self.backgroundShape = backgroundShape
    }

    var body: some View {
        if Self.verbose {
            os_log("\(self.t)开始渲染")
        }

        return Image.makeCoffeeReelIcon(
            useDefaultBackground: false,
            // x版本指向x点钟方向
            handleRotation: 0
        )
        .infinite()
        .background(backgroundShapeView)
        .shadow3xl()
        .rotationEffect(.degrees(rotationAngle))
        .onAppear {
            if rotationSpeed > 0 {
                startRotation()
            }
        }
    }

    @ViewBuilder
    private var backgroundShapeView: some View {
        if let background = background {
            switch backgroundShape {
            case .none:
                background
            case .circle:
                Circle().fill(background)
            case .rectangle:
                Rectangle().fill(background)
            case let .roundedRectangle(cornerRadius):
                RoundedRectangle(cornerRadius: cornerRadius).fill(background)
            case .capsule:
                Capsule().fill(background)
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
            .frame(width: 400, height: 250)

        LogoView(background: .blue.opacity(0.2), backgroundShape: .circle)
            .frame(width: 400, height: 250)

        LogoView(background: .green.opacity(0.2), backgroundShape: .roundedRectangle(cornerRadius: 20))
            .frame(width: 400, height: 250)

        LogoView(background: .orange.opacity(0.2), rotationSpeed: 0.5, backgroundShape: .capsule)
            .frame(width: 400, height: 250)
    }
    .frame(height: 800)
}

#Preview("LogoView - Snapshot") {
    LogoView()
        .background(LinearGradient.green2teal)
        .inMagicContainer(.init(width: 1024, height: 1024), scale: 0.5)
}

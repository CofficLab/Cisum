import MagicKit
import MagicPlayMan
import SwiftUI

/// 上一曲按钮
struct PreviousButton: View {
    @EnvironmentObject var man: PlayMan
    @Environment(\.demoMode) var isDemoMode

    private let size: CGFloat = 32

    var body: some View {
        Image.backward
            .font(.system(size: self.size * 0.6))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .inCard(.ultraThinMaterial)
            .roundedFull()
            .hoverScale(105)
            .inButtonWithAction {
                man.previous()
            }
            .shadowSm()
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

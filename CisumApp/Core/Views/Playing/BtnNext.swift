import MagicKit
import MagicPlayMan
import SwiftUI

/// 下一曲按钮
struct NextButton: View {
    @EnvironmentObject var man: PlayMan
    @Environment(\.demoMode) var isDemoMode

    private let size: CGFloat = 32

    var body: some View {
        Image.forward
            .font(.system(size: self.size * 0.6))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
            .inCard(.ultraThinMaterial)
            .roundedFull()
            .hoverScale(105)
            .inButtonWithAction {
                man.next()
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

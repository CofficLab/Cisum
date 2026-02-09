import MagicKit
import SwiftUI

struct BtnMore: View {
    @EnvironmentObject var app: AppProvider
    @Environment(\.demoMode) var isDemoMode

    private let size: CGFloat = 32

    var body: some View {
        Image.more
            .font(.system(size: self.size * 0.6))
            .frame(width: size, height: size)
            .foregroundStyle(.secondary)
            .inCard(.ultraThinMaterial)
            .roundedFull()
            .hoverScale(105)
            .inButtonWithAction {
                app.toggleDBView()
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

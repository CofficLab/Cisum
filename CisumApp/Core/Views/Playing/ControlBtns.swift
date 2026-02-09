import MagicKit
import OSLog
import SwiftUI

struct ControlBtns: View, SuperLog {
    @EnvironmentObject var app: AppProvider
    @EnvironmentObject var message: StateProvider

    nonisolated static let emoji = "🎵"
    static let verbose = false

    var body: some View {
        HStack(spacing: 4) {
            Spacer(minLength: 1)

            BtnMore()
            PreviousButton()
            PlayPauseButton()
            NextButton()
            PlayModeButton()

            Spacer(minLength: 1)
        }
        .padding(.bottom, 20)
        .infinite()
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

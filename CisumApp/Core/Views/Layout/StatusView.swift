import MagicKit
import SwiftUI

struct StatusView: View, SuperLog, SuperThread {
    nonisolated static let emoji = "📊"
    nonisolated static let verbose = false

    @EnvironmentObject var p: PluginProvider

    var body: some View {
        HStack {
            Spacer()
            ForEach(Array(p.getStatusViews().enumerated()), id: \.offset) { _, view in
                view
            }
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

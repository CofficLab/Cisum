import MagicKit

import OSLog
import SwiftData
import SwiftUI

struct TitleView: View, SuperLog, SuperThread {
    nonisolated static let verbose = false
    nonisolated static let emoji = "📺"

    @EnvironmentObject var playMan: PlayMan
    @Environment(\.demoMode) var isDemoMode

    var title: String {
        if isDemoMode {
            return String(localized: "清风徐来", table: "Core")
        } else {
            return playMan.asset?.deletingPathExtension().title ?? ""
        }
    }

    var body: some View {
        if Self.verbose {
            os_log("\(self.t)开始渲染")
        }

        return GeometryReader { geo in
            ZStack {
                Text(title)
                    .font(.system(size: 24))
                    .lineLimit(2)
                    .minimumScaleFactor(0.3)
                    .multilineTextAlignment(.center)
                    .frame(width: geo.size.width - 32)
                    .frame(maxHeight: .infinity)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .padding(.vertical)
                    .shadow3xl()
                    .foregroundStyle(.white)
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

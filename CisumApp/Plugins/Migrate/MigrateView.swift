import MagicKit

import OSLog
import SwiftUI

struct MigrateView: View, SuperThread {
    @EnvironmentObject var appManager: AppProvider
    @EnvironmentObject var m: StateProvider

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Text("Migrate", tableName: "Migrate")
            }
        }
    }
}

#Preview("App") {
    ContentView()
    .inRootView()
        .frame(height: 800)
}

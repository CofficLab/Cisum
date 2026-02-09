import MagicKit
import SwiftUI

struct BtnAdd: View {
    @EnvironmentObject var app: AppProvider

    var body: some View {
        Button(
            action: { app.isImporting = true },
            label: {
                Label(
                    title: { Text("添加") },
                    icon: { Image(systemName: "plus.circle") }
                )
            }
        )
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

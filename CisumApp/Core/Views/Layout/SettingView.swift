import SwiftUI

struct SettingView: View {
    @EnvironmentObject var p: PluginProvider

    var body: some View {
        ScrollView {
            VStack {
                ForEach(p.plugins.indices, id: \.self) { index in
                    p.plugins[index].addSettingView()
                }
            }.padding()
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

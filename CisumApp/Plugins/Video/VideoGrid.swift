import OSLog
import SwiftData
import SwiftUI

struct VideoGrid: View {
    static var label = "📬 DBTreeView::"

    @EnvironmentObject var app: AppProvider
    @EnvironmentObject var m: StateProvider
    @EnvironmentObject var playMan: PlayMan
    @EnvironmentObject var p: PluginProvider

    @State var selection: URL?
    @State var collapsed: Bool = false
    @State var icon: String = ""

    var disk: URL? {
//        p.currentScene?.getDisk()
        nil
    }

    var body: some View {
        ZStack {
            if let disk = disk {
//                List(disk.getChildren(),
//                     id: \.self,
//                     children: \.childrenOptional,
//                     selection: $selection
//                ) { file in
//                    VideoTile(selection: $selection, file: file)
//                        .tag(file as DiskFile?)
//                }
//                    .onAppear {
//                        self.icon = dataManager.isiCloudDisk ? "icloud" : "folder"
//                    }
//                    .onChange(of: selection, {
//                        if let s = selection, s.isNotFolder() {
//                            if playMan.playing {
//                                playMan.play(url: s.url)
//                            }
//                        }
//                    })
                //     .onChange(of: playMan.asset?.url, {
                //         if let asset = playMan.asset {
                //             self.selection = DiskFile(url: asset.url)
                //         } else {
                //             self.selection = nil
                //         }
                // }
                
//                )
                
                if app.isDropping || m.stateMessage.isEmpty && disk.getChildren().isEmpty {
//                    DBTips()
                }
            }
            
        }
    }
}

#Preview("App") {
    ContentView()
    .inRootView()
        .frame(height: 820)
}

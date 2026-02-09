import MagicKit

import OSLog
import SwiftUI

struct VideoTile: View, SuperThread, SuperLog {
    nonisolated static let emoji = "🎬"
    
    @EnvironmentObject var playMan: PlayMan

    @State var hovered = false
    @State var image: Image?

    @Binding var selection: URL?

    var file: URL

    var url: URL { file }

    var body: some View {
        ZStack {
            HStack {
                ZStack {
                    image
                        .scaleEffect(1.4)
                        .frame(width: 24, height: 36)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(url.title)
                    if url.isNotFolder {
                        HStack {
                            Text(url.getSizeReadable())

//                            if asset.like {
//                                Image(systemName: "star.fill")
//                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if hovered {
                HStack {
                    Spacer()
                    url.makeOpenButton()
//                    BtnMore(asset: asset, autoResize: false)
                }.labelStyle(.iconOnly)
            }
        }
        .onHover(perform: { hovered = $0 })
        .onTapGesture {
            self.selection = file
        }
        .contextMenu(menuItems: {
//            Divider()
//            BtnDownload(asset: asset)
//            BtnEvict(asset: asset)
//            if Config.isDesktop {
//                BtnShowInFinder(url: asset.url, autoResize: false)
//            }
//            Divider()
//            BtnDel(assets: [asset], autoResize: false)
        })
        .task {
//            self.image = try? await url.thumbnail(verbose: true, reason: self.className)
        }
    }
}

#Preview("App") {
    ContentView()
    .inRootView()
        .frame(height: 800)
}

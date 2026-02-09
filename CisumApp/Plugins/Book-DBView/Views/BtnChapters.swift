import OSLog
import SwiftData
import SwiftUI

struct BtnChapters: View {
    @EnvironmentObject var app: AppProvider
    @EnvironmentObject var playMan: PlayMan
    @EnvironmentObject var m: StateProvider
    @EnvironmentObject var db: DBSynced

    @State var isPresented = false
    @State var selection: URL?

    var asset: URL? { playMan.asset }
    var parent: URL? { asset?.getParent() }
    var items: [URL] {
        guard let bookURL = parent else {
            return []
        }

        return bookURL.getChildren()
    }

    var body: some View {
//        ControlButton(
//            title: "章节",
//            image: "book",
//            dynamicSize: true,
//            onTap: {
//                isPresented = true
//            })
//            .foregroundStyle(.white)
//            .popover(isPresented: $isPresented, content: {
//                List(items, id: \.self, selection: $selection) { file in
//                    ChapterTile(file: file)
//                        .tag(file as URL?)
//                }
//                .onAppear(perform: onAppear)
//                .onChange(of: selection, onSelectionChange)
//            })
    }
}

// MARK: Event Handler

extension BtnChapters {
    func onAppear() {
        if let asset = asset {
            selection = asset
        }
    }

    func onSelectionChange() {
        if let s = selection, s != asset {
//            playMan.play(s.toPlayAsset(), reason: "BtnChapters的Selection变了", verbose: true)
        }
    }
}

#Preview("APP") {
    ContentView()
    .inRootView()
        .frame(height: 800)
}


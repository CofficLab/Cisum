import OSLog
import SwiftUI

struct BtnChapters: View {
    @State var isPresented = false
    @State var selection: URL?

    var asset: URL? { nil }
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
        }
    }
}

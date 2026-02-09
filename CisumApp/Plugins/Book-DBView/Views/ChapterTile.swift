import SwiftUI

/**
 展示图书的章节
 */
struct ChapterTile: View {
    @EnvironmentObject var playMan: PlayMan
    
    var file: URL
    
    var chapters: [URL] { file.getChildren() }
    
    var body: some View {
        Text(file.title)
    }
}

#Preview {
    ContentView()
    .inRootView()
        .frame(height: 800)
}


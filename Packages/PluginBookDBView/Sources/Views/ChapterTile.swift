import SwiftUI

/**
 展示图书的章节
 */
struct ChapterTile: View {
    var file: URL
    
    var chapters: [URL] { file.getChildren() }
    
    var body: some View {
        Text(file.title)
    }
}

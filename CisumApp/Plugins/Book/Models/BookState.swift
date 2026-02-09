import Foundation
import SwiftData
import OSLog
import SwiftUI

/**
 记录一本有声书的状态数据，并通过 CloudKit 同步
 */
@Model
class BookState {
    /// 图书的URL
    var url: URL?
    
    /// 图书的文件的 Hash，多平台同步时用到
    var fileHash: String?
    
    /// 当前播放的章节的URL
    var currentURL: URL?
    
    /// 当前播放的章节的 Hash，多平台同步时用到
    var currentFileHash: String?
    
    /// 如果url是iCloud云盘的URL，relativePath=相对于iCloud云盘的路径；
    /// 如果url是本地的URL，relativePath=相对于container的路径。
    var relativePath: String?
    
    /// 播放进度
    var time: TimeInterval? = 0
    
    var createdAt: Date?
    var updateAt: Date?
    
    var currentTitle: String {
        currentURL?.lastPathComponent ?? "无"
    }
    
    init(url: URL, currentURL: URL? = nil, time: TimeInterval = 0) {
        self.url = url
        self.currentURL = currentURL
        self.time = time
        self.createdAt = .now
        self.updateAt = .now
    }
}

// MARK: Descriptor

extension BookState {
    static let descriptorAll = FetchDescriptor(predicate: #Predicate<BookState> { _ in
        return true
    }, sortBy: [])
    
    static func descriptorOf(_ url: URL) -> FetchDescriptor<BookState> {
        FetchDescriptor(predicate: #Predicate<BookState> { s in
            s.url == url
        }, sortBy: [
            SortDescriptor(\.createdAt, order: .forward)
        ])
    }
}

// MARK: - Preview

#if os(macOS)
#Preview("App - Large") {
    ContentView()
    .inRootView()
        .frame(width: 600, height: 1000)
}
#Preview("App - Small") {
    ContentView()
    .inRootView()
        .frame(width: 600, height: 600)
}
#endif

#if os(iOS)
#Preview("iPhone") {
    ContentView()
    .inRootView()
}
#endif


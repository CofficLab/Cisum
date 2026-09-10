import Foundation
import ProviderBook
import SwiftData
import OSLog
import SwiftUI

/**
 记录一本有声书的状态数据，并通过 CloudKit 同步
 */
@Model
public class BookState {
    /// 图书的URL
    public var url: URL?
    
    /// 图书的文件的 Hash，多平台同步时用到
    public var fileHash: String?
    
    /// 当前播放的章节的URL
    public var currentURL: URL?
    
    /// 当前播放的章节的 Hash，多平台同步时用到
    public var currentFileHash: String?
    
    /// 如果url是iCloud云盘的URL，relativePath=相对于iCloud云盘的路径；
    /// 如果url是本地的URL，relativePath=相对于container的路径。
    public var relativePath: String?
    
    /// 播放进度
    public var time: TimeInterval? = 0
    
    public var createdAt: Date?
    public var updateAt: Date?
    
    public var currentTitle: String {
        currentURL?.lastPathComponent ?? "None"
    }
    
    public init(url: URL, currentURL: URL? = nil, time: TimeInterval = 0) {
        self.url = url
        self.currentURL = currentURL
        self.time = time
        self.createdAt = .now
        self.updateAt = .now
    }
}

// MARK: Descriptor

extension BookState {
    public static let descriptorAll = FetchDescriptor(predicate: #Predicate<BookState> { _ in
        return true
    }, sortBy: [])
    
    public static func descriptorOf(_ url: URL) -> FetchDescriptor<BookState> {
        FetchDescriptor(predicate: #Predicate<BookState> { s in
            s.url == url
        }, sortBy: [
            SortDescriptor(\.createdAt, order: .forward)
        ])
    }

    public static func representsSameBookURL(_ storedURL: URL?, as url: URL) -> Bool {
        guard let storedURL else { return false }
        return BookPathContainment.representsSameFile(storedURL, url)
    }
}

import Foundation
import ProviderBook
import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif

/// 有声书封面区的状态容器。
///
/// 播放与书库变化由 `BookHeroObserver` 写入；封面从书库读取，读取结果按
/// 请求代际丢弃过期响应，避免快速切章时封面错位。
@MainActor
final class BookHeroViewModel: ObservableObject {
    @Published private(set) var subject: BookHeroSubject?
    @Published private(set) var cover: Image?

    private weak var playback: (any BookHeroPlaybackCapability)?
    private weak var library: (any BookHeroLibraryCapability)?

    private var currentURL: URL?
    private var books: [BookDTO] = []
    private var booksLoaded = false
    private var generation = 0

    init(
        playback: (any BookHeroPlaybackCapability)?,
        library: (any BookHeroLibraryCapability)?
    ) {
        self.playback = playback
        self.library = library
        self.currentURL = playback?.currentURL
        refreshBooks()
    }

    /// 是否展示当前章节（书名 + 章节）。
    var isHeroVisible: Bool { subject != nil }

    /// 是否展示「选一本有声书开始收听」占位：有声书场景里没有正在播放的书籍章节。
    ///
    /// 不要求书库非空：空仓库的导入引导在内容区，控制区仍可提示用户挑一本书。
    var showsIdlePlaceholder: Bool { subject == nil }

    func applyAssetChanged(_ url: URL?) {
        guard url != currentURL else { return }
        currentURL = url
        resolveCurrent()
    }

    func applyLibraryChanged() {
        refreshBooks()
    }

    private func refreshBooks() {
        Task { [weak self] in
            guard let self, let library = self.library else { return }
            let loaded = await library.books()
            self.books = loaded
            self.booksLoaded = true
            self.resolveCurrent()
        }
    }

    private func resolveCurrent() {
        generation += 1
        let generation = generation

        guard let url = currentURL, isBookAsset(url) else {
            subject = nil
            cover = nil
            return
        }

        // 书库列表还没加载完时先用章节名兜底，加载完再换成书名。
        let resolved = booksLoaded
            ? BookHeroSubjectResolver.resolve(chapterURL: url, books: books)
            : BookHeroSubject(
                bookTitle: url.deletingPathExtension().lastPathComponent,
                chapterTitle: nil,
                bookURL: nil
            )
        subject = resolved
        cover = nil

        guard let bookURL = resolved.bookURL else { return }
        Task { [weak self] in
            guard let self, let library = self.library else { return }
            let data = await library.coverData(for: bookURL)
            guard let image = Self.image(from: data), generation == self.generation else { return }
            self.cover = image
        }
    }

    private static func image(from data: Data?) -> Image? {
        guard let data else { return nil }
#if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
#elseif os(iOS) || os(visionOS)
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
#else
        return nil
#endif
    }

    /// 当前播放文件是否属于有声书库。
    ///
    /// 切场景只停止播放、不重置引擎，音乐曲目会继续留在 `currentURL`；
    /// 不按书库边界过滤会把音乐文件名当成书名显示。
    private func isBookAsset(_ url: URL) -> Bool {
        guard let disk = library?.bookDisk else { return false }
        let diskPath = Self.stablePath(for: disk)
        let assetPath = Self.stablePath(for: url)
        let prefix = diskPath.hasSuffix("/") ? diskPath : diskPath + "/"
        return assetPath == diskPath || assetPath.hasPrefix(prefix)
    }

    private static func stablePath(for url: URL) -> String {
        if FileManager.default.fileExists(atPath: url.path) {
            return url.resolvingSymlinksInPath().standardizedFileURL.path
        }
        return url.standardizedFileURL.path
    }
}

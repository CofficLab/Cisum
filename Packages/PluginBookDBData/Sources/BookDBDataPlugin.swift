import CisumProviderStorage
import KernelCore
import ProviderPlugin
import KitAppEvents
import OSLog
import ProviderBook
import Foundation

/// 有声书数据库数据层插件。
///
/// 该插件是书籍 SwiftData 容器、BookRepo 和文件库监听的唯一组装入口；
/// UI 插件通过 `BookDatabaseProviding` 使用它，不再自行构造数据库。
@MainActor
public final class BookDBDataPlugin: AsyncSuperPlugin {
    public let id = "com.coffic.cisum.plugin.book-db-data"

    public static let shared = BookDBDataPlugin()
    public let order = 11
    public let iconName = "externaldrive.badge.timemachine"
    public let metadata = PluginMetadata(
        id: "com.coffic.cisum.plugin.book-db-data",
        name: "Audiobook Database Data",
        description: "Provides the audiobook database and repository service.",
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var provider: BookDatabaseProvider?

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        try installProvider(kernel: kernel)
    }

    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        try installProvider(kernel: kernel)
        seedUITestBooksIfRequested()
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        try installProvider(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        removeProvider(from: kernel)
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        removeProvider(from: kernel)
        self.kernel = nil
    }

    @MainActor
    private func installProvider(kernel: KernelCoreContainer) throws {
        guard provider == nil, let storage = kernel.resolveProvider((any StorageProviding).self) else { return }
        let provider = BookDatabaseProvider(storage: storage)
        do {
            try kernel.registerProvider(BookDatabaseProviding.self, provider)
            self.provider = provider
        } catch {
            provider.shutdown()
            throw error
        }
    }

    @MainActor
    private func removeProvider(from kernel: KernelCoreContainer) {
        guard provider != nil else { return }
        provider?.shutdown()
        kernel.unregisterProvider(BookDatabaseProviding.self)
        provider = nil
    }

    // MARK: - UI test support

    /// 在有声书仓库里创建确定性的书籍数据，让 UI 测试不必依赖真实文件。
    ///
    /// ## 启动参数
    ///
    /// `--cisum-ui-testing-seed-book <书籍描述>`，描述语法见
    /// ``UITestBookSeedTone/parseBooks(from:)-8r6ko``：
    ///
    /// - `MyBook` —— 一本书，含一个默认章节；
    /// - `MyBook/Chapter 01.wav,Chapter 02.wav` —— 显式指定章节；
    /// - `BookA;BookB` —— 多本书（分号分隔）。
    ///
    /// ## 与音乐侧的对应关系
    ///
    /// 音乐侧有 `--cisum-ui-testing-seed-audio`，有声书侧此前**完全没有**
    /// 造数能力——有声书 UI 测试只能断言空状态，覆盖不到「仓库里有一本书」
    /// 的分支。本方法补上这一块，且刻意与音频侧保持同一套语义：
    ///
    /// - 合成**真实可解码**的 PCM WAV，播放进度类断言拿得到真实内容；
    /// - 书籍以「目录 + 章节文件」的形态创建，与用户真实拖入书籍文件夹
    ///   的路径一致，因此覆盖的是真实的目录扫描与索引逻辑。
    @MainActor
    private func seedUITestBooksIfRequested() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--cisum-ui-testing"),
              let index = arguments.firstIndex(of: "--cisum-ui-testing-seed-book"),
              arguments.indices.contains(index + 1),
              let disk = provider?.bookDisk else { return }

        let books = UITestBookSeedTone.parseBooks(from: arguments[index + 1])
        guard !books.isEmpty else { return }

        // 可选的时长覆写：长章节让基于进度的断言有观察窗口。
        var duration = UITestBookSeedTone.defaultDuration
        if let durationIndex = arguments.firstIndex(of: "--cisum-ui-testing-seed-duration"),
           arguments.indices.contains(durationIndex + 1),
           let parsed = TimeInterval(arguments[durationIndex + 1]), parsed > 0 {
            duration = parsed
        }

        for book in books {
            let bookDirectory = disk.appendingPathComponent(book.name, isDirectory: true)
            do {
                try FileManager.default.createDirectory(
                    at: bookDirectory,
                    withIntermediateDirectories: true
                )
                let data = UITestBookSeedTone.makeWAV(duration: duration)
                for chapter in book.chapters {
                    let url = bookDirectory.appendingPathComponent(chapter, isDirectory: false)
                    try data.write(to: url, options: .atomic)
                }
            } catch {
                os_log(.error, "❌ UI test book seed failed for \(book.name): \(error.localizedDescription)")
            }
        }
        #endif
    }
}

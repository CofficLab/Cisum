import Foundation
import Testing
@testable import PluginAudioDBView

// MARK: - 文件大小读取策略

/// 文件大小的读取要处理 Foundation 的多种数值装箱类型（`NSNumber` / `Int` /
/// `Int64` / `UInt64`），并且**负数与超大值必须被收敛**——读数异常时
/// 静默显示一个离谱的数字比显示「不可用」更糟。
@Suite("列表项文件大小读取策略")
struct AudioItemFileSizeReadPolicyTests {
    @Test("NSNumber 读取为字节数")
    func readsNSNumberSize() {
        #expect(AudioItemFileSizeReadPolicy.fileSize(from: [.size: NSNumber(value: 1024)]) == 1024)
    }

    @Test("负数被收敛为 0")
    func clampsNegativeSize() {
        #expect(AudioItemFileSizeReadPolicy.fileSize(from: [.size: NSNumber(value: -1)]) == 0)
        #expect(AudioItemFileSizeReadPolicy.fileSize(from: [.size: -5]) == 0)
    }

    @Test("Int 装箱被正确读取")
    func readsIntSize() {
        #expect(AudioItemFileSizeReadPolicy.fileSize(from: [.size: 2048]) == 2048)
    }

    @Test("Int64 装箱被正确读取")
    func readsInt64Size() {
        #expect(AudioItemFileSizeReadPolicy.fileSize(from: [.size: Int64(4096)]) == 4096)
    }

    @Test("UInt64 装箱被正确读取")
    func readsUInt64Size() {
        #expect(AudioItemFileSizeReadPolicy.fileSize(from: [.size: UInt64(8192)]) == 8192)
    }

    @Test("超过 Int64.max 的 UInt64 被收敛为 Int64.max")
    func clampsOverflowingUInt64() {
        #expect(AudioItemFileSizeReadPolicy.fileSize(from: [.size: UInt64.max]) == Int64.max)
    }

    @Test("缺少 size 属性时返回 nil")
    func returnsNilWithoutSizeAttribute() {
        #expect(AudioItemFileSizeReadPolicy.fileSize(from: [:]) == nil)
        #expect(AudioItemFileSizeReadPolicy.fileSize(from: [.creationDate: Date()]) == nil)
    }

    @Test("无法归一为整数的类型返回 nil")
    func returnsNilForUnsupportedType() {
        #expect(AudioItemFileSizeReadPolicy.fileSize(from: [.size: "1024"]) == nil)
    }

    @Test("磁盘上不存在的文件读不到大小")
    func currentFileSizeOfMissingFileIsNil() {
        let missing = URL(fileURLWithPath: "/tmp/cisum-definitely-missing-\(UUID().uuidString).mp3")
        #expect(AudioItemFileSizeReadPolicy.currentFileSize(for: missing) == nil)
    }

    @Test("磁盘上真实文件读出真实字节数")
    func currentFileSizeReadsRealFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let file = root.appendingPathComponent("track.mp3")
        let payload = Data(repeating: 0xAB, count: 4096)
        try payload.write(to: file)

        #expect(AudioItemFileSizeReadPolicy.currentFileSize(for: file) == 4096)
    }
}

// MARK: - 文件大小展示状态

@Suite("列表项文件大小展示状态")
struct AudioItemFileSizeDisplayPolicyTests {
    @Test("有大小则展示大小")
    func showsSizeWhenAvailable() {
        #expect(AudioItemFileSizeDisplayPolicy.state(fileSize: 100, isUnavailable: false) == .size(100))
        // 即使仓库不可用，只要读到了大小就展示大小。
        #expect(AudioItemFileSizeDisplayPolicy.state(fileSize: 100, isUnavailable: true) == .size(100))
    }

    @Test("读不到且仓库不可用则展示不可用")
    func showsUnavailableWhenRepositoryUnavailable() {
        #expect(AudioItemFileSizeDisplayPolicy.state(fileSize: nil, isUnavailable: true) == .unavailable)
    }

    @Test("读不到但仓库可用则保持加载中")
    func staysLoadingWhenRepositoryAvailable() {
        #expect(AudioItemFileSizeDisplayPolicy.state(fileSize: nil, isUnavailable: false) == .loading)
    }
}

// MARK: - 文件大小缓存

/// 缓存**只存成功读到的值**：失败必须可重试，否则 iCloud 占位文件下载完成后
/// 仍然永远显示「不可用」。
@Suite("列表项文件大小缓存")
@MainActor
struct AudioItemFileSizeCacheTests {
    private func makeTemporaryFile(_ name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent(name)
        try Data(repeating: 0, count: 16).write(to: file)
        return file
    }

    @Test("缓存空时读取不到")
    func cacheStartsEmpty() throws {
        let file = try makeTemporaryFile("a.mp3")
        defer { AudioItemFileSizeCache.removeAll() }

        #expect(AudioItemFileSizeCache.cachedSize(for: file) == nil)
    }

    @Test("存入后能读回")
    func storesAndReadsBack() throws {
        let file = try makeTemporaryFile("b.mp3")
        defer { AudioItemFileSizeCache.removeAll() }

        AudioItemFileSizeCache.store(2048, for: file)
        #expect(AudioItemFileSizeCache.cachedSize(for: file) == .some(2048))
    }

    @Test("失败结果不写入缓存")
    func doesNotCacheFailure() throws {
        let file = try makeTemporaryFile("c.mp3")
        defer { AudioItemFileSizeCache.removeAll() }

        // `nil` 表示读取失败：必须保持「没有缓存」，以便后续重试。
        AudioItemFileSizeCache.store(nil, for: file)
        #expect(AudioItemFileSizeCache.cachedSize(for: file) == nil)
    }

    @Test("移除指定文件后缓存失效")
    func removeDropsEntry() throws {
        let file = try makeTemporaryFile("d.mp3")
        defer { AudioItemFileSizeCache.removeAll() }

        AudioItemFileSizeCache.store(100, for: file)
        AudioItemFileSizeCache.remove([file])
        #expect(AudioItemFileSizeCache.cachedSize(for: file) == nil)
    }

    @Test("批量移除只影响目标文件")
    func removeOnlyAffectsTargets() throws {
        let kept = try makeTemporaryFile("keep.mp3")
        let removed = try makeTemporaryFile("drop.mp3")
        defer { AudioItemFileSizeCache.removeAll() }

        AudioItemFileSizeCache.store(1, for: kept)
        AudioItemFileSizeCache.store(2, for: removed)

        AudioItemFileSizeCache.remove([removed])

        #expect(AudioItemFileSizeCache.cachedSize(for: kept) == .some(1))
        #expect(AudioItemFileSizeCache.cachedSize(for: removed) == nil)
    }

    @Test("清空全部缓存")
    func removeAllClearsEverything() throws {
        let first = try makeTemporaryFile("e.mp3")
        let second = try makeTemporaryFile("f.mp3")
        defer { AudioItemFileSizeCache.removeAll() }

        AudioItemFileSizeCache.store(1, for: first)
        AudioItemFileSizeCache.store(2, for: second)

        AudioItemFileSizeCache.removeAll()

        #expect(AudioItemFileSizeCache.cachedSize(for: first) == nil)
        #expect(AudioItemFileSizeCache.cachedSize(for: second) == nil)
    }

    @Test("同一文件的等价路径命中同一条缓存")
    func equivalentPathsShareCacheEntry() throws {
        let file = try makeTemporaryFile("g.mp3")
        defer { AudioItemFileSizeCache.removeAll() }

        AudioItemFileSizeCache.store(4096, for: file)

        // 带 `..` 与 `./` 的等价路径必须命中同一条缓存。
        let equivalent = file
            .deletingLastPathComponent()
            .appendingPathComponent("./")
            .appendingPathComponent(file.lastPathComponent)
        #expect(AudioItemFileSizeCache.cachedSize(for: equivalent) == .some(4096))
    }
}

// MARK: - 加载策略身份归一

@Suite("列表项文件身份归一")
struct AudioListFileIdentityTests {
    @Test("同一路径的归一身份一致")
    func samePathHasSameIdentity() {
        let url = URL(fileURLWithPath: "/tmp/music/track.mp3")
        #expect(AudioListFileIdentity.canonicalIdentity(for: url) == AudioListFileIdentity.canonicalIdentity(for: url))
    }

    @Test("不同路径的归一身份不同")
    func differentPathsHaveDifferentIdentity() {
        let first = URL(fileURLWithPath: "/tmp/music/a.mp3")
        let second = URL(fileURLWithPath: "/tmp/music/b.mp3")
        #expect(AudioListFileIdentity.canonicalIdentity(for: first) != AudioListFileIdentity.canonicalIdentity(for: second))
    }
}

// MARK: - 加载延迟开关（UI 测试启动参数）

/// UI 测试用启动参数必须解析严格：坏参数不能被静默当成「不延迟」，
/// 否则测试会以「骨架没出现」的形式失败，掩盖真正的原因。
@Suite("音频库首屏加载延迟开关")
struct AudioLibraryLoadDelayControlTests {
    @Test("无参数时不延迟")
    func noArgumentMeansNoDelay() {
        #expect(AudioLibraryLoadDelayControl.firstPageDelay(arguments: []) == nil)
        #expect(AudioLibraryLoadDelayControl.firstPageDelay(arguments: ["--other=3"]) == nil)
    }

    @Test("解析等号形式的秒数")
    func parsesEqualsForm() {
        #expect(AudioLibraryLoadDelayControl.firstPageDelay(arguments: ["--cisum-ui-testing-audio-load-delay=5"]) == 5)
    }

    @Test("解析空格形式")
    func parsesSpaceForm() {
        #expect(AudioLibraryLoadDelayControl.firstPageDelay(arguments: ["--cisum-ui-testing-audio-load-delay 7"]) == 7)
    }

    @Test("允许小数秒数")
    func parsesFractionalSeconds() {
        #expect(AudioLibraryLoadDelayControl.firstPageDelay(arguments: ["--cisum-ui-testing-audio-load-delay=1.5"]) == 1.5)
    }

    @Test("超过上限时被封顶")
    func clampsToMaximum() {
        #expect(AudioLibraryLoadDelayControl.firstPageDelay(arguments: ["--cisum-ui-testing-audio-load-delay=9999"]) == 30)
    }

    @Test("非正数不延迟")
    func nonPositiveMeansNoDelay() {
        #expect(AudioLibraryLoadDelayControl.firstPageDelay(arguments: ["--cisum-ui-testing-audio-load-delay=0"]) == nil)
        #expect(AudioLibraryLoadDelayControl.firstPageDelay(arguments: ["--cisum-ui-testing-audio-load-delay=-5"]) == nil)
    }

    @Test("非数值参数不延迟")
    func nonNumericMeansNoDelay() {
        #expect(AudioLibraryLoadDelayControl.firstPageDelay(arguments: ["--cisum-ui-testing-audio-load-delay=abc"]) == nil)
    }

    @Test("非有限数值不延迟")
    func nonFiniteMeansNoDelay() {
        #expect(AudioLibraryLoadDelayControl.firstPageDelay(arguments: ["--cisum-ui-testing-audio-load-delay=inf"]) == nil)
    }

    @Test("只取第一个匹配的参数")
    func usesFirstMatchingArgument() {
        let arguments = [
            "--cisum-ui-testing-audio-load-delay=2",
            "--cisum-ui-testing-audio-load-delay=9",
        ]
        #expect(AudioLibraryLoadDelayControl.firstPageDelay(arguments: arguments) == 2)
    }
}

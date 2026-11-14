import AVFoundation
import Foundation
import Testing
@testable import PluginBookDBData

// MARK: - 种子书籍解析

/// `--cisum-ui-testing-seed-book` 的取值解析。
///
/// 这些用例只测纯函数（解析），不触碰文件系统——因此完全确定，
/// 与运行机器的环境无关。
@Test func parsesSingleBookWithDefaultChapter() {
    let books = UITestBookSeedTone.parseBooks(from: "MyBook")
    #expect(books.count == 1)
    #expect(books.first?.name == "MyBook")
    #expect(books.first?.chapters == ["Chapter 01.wav"])
}

@Test func parsesBookWithExplicitChapters() {
    let books = UITestBookSeedTone.parseBooks(from: "MyBook/Chapter 01.wav,Chapter 02.wav")
    #expect(books.count == 1)
    #expect(books.first?.name == "MyBook")
    #expect(books.first?.chapters == ["Chapter 01.wav", "Chapter 02.wav"])
}

@Test func parsesMultipleBooksSeparatedBySemicolon() {
    let books = UITestBookSeedTone.parseBooks(from: "BookA;BookB/Chapter 01.wav")
    #expect(books.count == 2)
    #expect(books.map(\.name) == ["BookA", "BookB"])
    #expect(books[0].chapters == ["Chapter 01.wav"])
    #expect(books[1].chapters == ["Chapter 01.wav"])
}

@Test func rejectsEmptyAndMalformedSeedValues() {
    #expect(UITestBookSeedTone.parseBooks(from: "").isEmpty)
    #expect(UITestBookSeedTone.parseBooks(from: "   ").isEmpty)
    #expect(UITestBookSeedTone.parseBooks(from: "/Chapter 01.wav").isEmpty)
    #expect(UITestBookSeedTone.parseBooks(from: "MyBook/").isEmpty)
}

/// 数据保真：造出的章节必须是仓库**真的会索引**的音频格式。
///
/// 若种子章节是 `notes.txt`，目录扫描根本不会把它当成可播放内容，
/// UI 测试会得到一个「有目录但没有书」的仓库——测的是我们想象的世界，
/// 不是真实路径。因此不受支持的扩展名必须被直接拒绝。
@Test func rejectsChaptersWithUnsupportedExtensions() {
    #expect(UITestBookSeedTone.parseBooks(from: "MyBook/notes.txt").isEmpty)
    #expect(UITestBookSeedTone.parseBooks(from: "MyBook/Chapter 01.wav,notes.txt")
        .first?.chapters == ["Chapter 01.wav"])
    // 受支持的扩展名（含大小写混合）必须被接受。
    #expect(UITestBookSeedTone.parseBooks(from: "MyBook/Chapter 01.M4B")
        .first?.chapters == ["Chapter 01.M4B"])
}

// MARK: - 合成波形

/// 合成出的 WAV 必须能被系统解码器真实读出——
/// 占位字节无法支撑「进度随播放推进」这类断言。
@Test func seededWAVIsDecodableBySystemAudioDecoder() throws {
    let data = UITestBookSeedTone.makeWAV(duration: 0.5)
    #expect(!data.isEmpty)

    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("UITestBookSeed-\(UUID().uuidString).wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try data.write(to: url)

    let file = try #require(try AVAudioFile(forReading: url))
    #expect(file.length > 0)
    #expect(file.processingFormat.sampleRate == UITestBookSeedTone.sampleRate)
    #expect(file.processingFormat.channelCount == 1)
}

@Test func seededWAVRejectsNonPositiveDurationByFallingBack() {
    // 非法时长回退到默认值：产物仍是合法 WAV，不是空壳。
    let fallback = UITestBookSeedTone.makeWAV(duration: 0)
    let explicit = UITestBookSeedTone.makeWAV(duration: UITestBookSeedTone.defaultDuration)
    #expect(!fallback.isEmpty)
    #expect(fallback.count == explicit.count)
}

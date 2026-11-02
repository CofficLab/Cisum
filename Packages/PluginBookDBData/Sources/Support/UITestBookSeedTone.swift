import Foundation

/// UI 测试种子有声书的合成器。
///
/// ## 与音频侧的对应关系
///
/// 音乐仓库的种子数据由 `UITestAudioSeedTone` 合成（`PluginAudioDBData`），
/// 有声书侧此前**完全没有**造数能力——有声书 UI 测试只能断言空状态，
/// 无法覆盖「仓库里有一本书」的分支。
///
/// 本类型补上这一块，语义与音频侧对齐：
///
/// - 合成**真实可解码**的 16-bit PCM WAV（而不是占位字节），
///   这样播放进度、章节切换这类断言能拿到真实的可播放内容；
/// - 不往仓库里塞二进制 fixture，纯 `Foundation` 写字节，无新依赖。
///
/// ## 有声书仓库的结构
///
/// 有声书仓库里的「一本书」是**文件夹**，章节是其中的音频文件；
/// 单文件书籍则直接是音频文件。种子数据因此按「书籍目录 + 章节文件」
/// 的形态创建，与真实用户拖入书籍文件夹的路径一致。
enum UITestBookSeedTone {
    /// 默认时长（秒）。
    static let defaultDuration: TimeInterval = 60

    /// 采样率（Hz）。44.1kHz 是最通用的取值。
    static let sampleRate: Double = 44_100

    /// 音调频率（Hz）。440Hz 标准 A（a4），解码器易确认。
    static let frequency: Double = 440

    /// 峰值振幅（0...1）。留出余量避免削顶失真干扰解码。
    private static let amplitude = 0.5

    /// 一本种子书的描述。
    struct SeedBook {
        /// 书籍目录名（相对于有声书仓库根）。
        let name: String
        /// 章节文件名（相对于书籍目录）。
        let chapters: [String]
    }

    /// 解析 `--cisum-ui-testing-seed-book` 的取值。
    ///
    /// 支持两种形态：
    ///
    /// - `BookName` —— 一本书，含一个默认章节 `Chapter 01.wav`；
    /// - `BookName/Chapter 01.wav,Chapter 02.wav` —— 显式指定章节列表。
    ///
    /// 分隔符用 `/`（书籍目录与章节文件名的自然分隔），逗号分隔多个章节。
    ///
    /// - Parameter value: 原始取值。
    /// - Returns: 解析出的书籍列表；无法解析时返回空数组。
    static func parseBooks(from value: String) -> [SeedBook] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return trimmed
            .components(separatedBy: ";")
            .compactMap { entry -> SeedBook? in
                // 用 `components(separatedBy:)` 而非 `split(separator:)`：
                // 后者会静默丢弃空段，`"/Chapter 01.wav"` 会被误当成书名，
                // `"MyBook/"` 的空章节列表也会被误当成「无章节」。
                let parts = entry.components(separatedBy: "/").map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                guard let bookName = parts.first, !bookName.isEmpty else { return nil }

                guard parts.count > 1 else {
                    return SeedBook(name: bookName, chapters: [Self.defaultChapterName])
                }

                let chapters = parts[1]
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    // 只接受有声书仓库支持的音频扩展名。
                    //
                    // 数据保真：造出的章节若不是可播放格式，目录扫描根本不会
                    // 索引它，UI 测试会得到一个「有目录但没有书」的仓库——
                    // 测的是我们想象的世界，不是真实路径。
                    .filter { Self.supportedExtensions.contains(
                        URL(fileURLWithPath: $0).pathExtension.lowercased()
                    ) }
                guard !chapters.isEmpty else { return nil }
                return SeedBook(name: bookName, chapters: chapters)
            }
    }

    /// 有声书仓库支持的音频扩展名。
    ///
    /// 与 ``BookPluginInfo/supportedExtensions`` 保持一致：种子数据必须
    /// 落在真实索引路径能识别的格式上。
    static let supportedExtensions: Set<String> = [
        "mp3", "m4a", "m4b", "aac", "wav", "aiff", "flac", "ogg", "opus", "alac",
    ]

    /// 默认章节文件名。
    static let defaultChapterName = "Chapter 01.wav"

    /// 合成一段可解码的 WAV 数据。
    ///
    /// - Parameter duration: 时长（秒），非正值时回退到 ``defaultDuration``。
    /// - Returns: 完整 WAV 文件字节。
    static func makeWAV(duration: TimeInterval) -> Data {
        let frames = max(1, Int((duration.isFinite && duration > 0 ? duration : defaultDuration) * sampleRate))

        // 16-bit 有符号小端 PCM。
        let bytesPerSample = 2
        let dataByteCount = frames * bytesPerSample
        let data = sineWaveData(frames: frames)

        var wav = Data()
        wav.reserveCapacity(44 + dataByteCount)

        // RIFF 容器
        wav.append(contentsOf: Array("RIFF".utf8))
        wav.appendLE(UInt32(36 + dataByteCount))
        wav.append(contentsOf: Array("WAVE".utf8))

        // fmt 块
        wav.append(contentsOf: Array("fmt ".utf8))
        wav.appendLE(UInt32(16))                 // Subchunk1Size (PCM)
        wav.appendLE(UInt16(1))                  // AudioFormat = PCM
        wav.appendLE(UInt16(1))                  // NumChannels = mono
        wav.appendLE(UInt32(Int(sampleRate)))
        wav.appendLE(UInt32(Int(sampleRate) * bytesPerSample)) // ByteRate
        wav.appendLE(UInt16(bytesPerSample))     // BlockAlign
        wav.appendLE(UInt16(16))                 // BitsPerSample

        // data 块
        wav.append(contentsOf: Array("data".utf8))
        wav.appendLE(UInt32(dataByteCount))
        wav.append(data)

        return wav
    }

    /// 生成单声道 16-bit 小端正弦波采样。
    private static func sineWaveData(frames: Int) -> Data {
        var data = Data()
        data.reserveCapacity(frames * 2)

        let step = 2 * Double.pi * frequency / sampleRate
        for frame in 0..<frames {
            let value = amplitude * sin(step * Double(frame))
            let clamped = max(-1, min(1, value))
            data.appendLE(Int16(clamped * Double(Int16.max)))
        }
        return data
    }
}

private extension Data {
    /// 以小端序追加一个多字节整数。
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}

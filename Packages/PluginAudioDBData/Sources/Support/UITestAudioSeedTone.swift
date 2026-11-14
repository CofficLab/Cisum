import Foundation

/// UI 测试种子音频的合成器。
///
/// 用途：`AudioDBDataPlugin` 在 `--cisum-ui-testing-seed-audio <name>` 下需要往
/// App 沙盒写一个音频文件，让 UI 测试不必驱动系统文件选择器就能命中仓库列表。
///
/// 早期实现写入的是 `Data([0])`（单字节占位文件）。这对「列表里出现一行」
/// 这类断言够用，但播放回归无法进行：引擎解不出 PCM 流，
/// 「进度随播放推进」「切歌后进度归零」这两类断言拿不到可推进的进度值。
///
/// 这里改为在运行时合成一段真实的 16-bit PCM WAV（RIFF/WAVE 容器），
/// 既不往仓库里塞二进制 fixture，也不引入新依赖 —— 纯 `Foundation` 写字节。
enum UITestAudioSeedTone {
    /// 默认时长（秒）。足够长，使基于进度的断言有时间观察到推进。
    static let defaultDuration: TimeInterval = 60

    /// 采样率（Hz）。44.1kHz 是最通用的取值。
    static let sampleRate: Double = 44_100

    /// 音调频率（Hz）。440Hz 标准 A（a4），人耳与解码器都易确认。
    static let frequency: Double = 440

    /// 峰值振幅（0...1）。留出余量避免削顶失真干扰解码。
    private static let amplitude = 0.5

    /// 合成一段可解码的 WAV 数据。
    ///
    /// - Parameter duration: 时长（秒），非正值时回退到 ``defaultDuration``。
    /// - Returns: 完整 WAV 文件字节；duration 非法时返回 44 字节的空头容器。
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
        wav.appendLE(UInt32(36 + dataByteCount)) // ChunkSize
        wav.append(contentsOf: Array("WAVE".utf8))

        // fmt 块
        wav.append(contentsOf: Array("fmt ".utf8))
        wav.appendLE(UInt32(16))                 // Subchunk1Size (PCM)
        wav.appendLE(UInt16(1))                  // AudioFormat = PCM
        wav.appendLE(UInt16(1))                  // NumChannels = mono
        wav.appendLE(UInt32(Int(sampleRate)))    // SampleRate
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

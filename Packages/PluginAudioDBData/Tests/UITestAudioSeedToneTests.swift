import AVFoundation
import Foundation
import Testing
@testable import PluginAudioDBData

/// `--cisum-ui-testing-seed-audio` 生成的 WAV 必须能被系统解码器真实读出，
/// 否则播放类 UI 回归（进度推进、切歌归零）无法在 iOS 上运行。
@Suite("UITestAudioSeedTone")
struct UITestAudioSeedToneTests {
    @Test("生成符合 RIFF/WAVE 规范的容器头")
    func producesValidRIFFHeader() {
        let data = UITestAudioSeedTone.makeWAV(duration: 1)

        #expect(data.count > 44, "WAV 数据应包含头部之外的采样数据")
        #expect(data.prefix(4) == Data("RIFF".utf8))
        #expect(data.subdata(in: 8..<12) == Data("WAVE".utf8))
        #expect(data.subdata(in: 12..<16) == Data("fmt ".utf8))
        #expect(data.subdata(in: 36..<40) == Data("data".utf8))

        // fmt 块声明必须是单声道 16-bit PCM。
        #expect(readUInt16(data, at: 20) == 1, "AudioFormat 应为 PCM")
        #expect(readUInt16(data, at: 22) == 1, "应为单声道")
        #expect(readUInt16(data, at: 34) == 16, "BitsPerSample 应为 16")
        #expect(readUInt32(data, at: 24) == UInt32(UITestAudioSeedTone.sampleRate))
    }

    @Test("头部声明的块大小与实际数据一致")
    func chunkSizesMatchPayload() {
        let data = UITestAudioSeedTone.makeWAV(duration: 1)
        let dataByteCount = readUInt32(data, at: 40)
        let riffSize = readUInt32(data, at: 4)

        #expect(dataByteCount == UInt32(data.count - 44), "data 块大小应等于实际采样字节数")
        #expect(riffSize == UInt32(data.count - 8), "RIFF 块大小应等于总长度减 8")
        // 1 秒 @44.1kHz 单声道 16-bit
        #expect(dataByteCount == UInt32(UITestAudioSeedTone.sampleRate) * 2)
    }

    @Test("时长越长数据越大")
    func durationScalesPayload() {
        let short = UITestAudioSeedTone.makeWAV(duration: 1)
        let long = UITestAudioSeedTone.makeWAV(duration: 2)
        #expect(long.count > short.count)
    }

    @Test("非法时长回退到默认值而非产生空文件")
    func invalidDurationFallsBackToDefault() {
        for invalid in [0, -1, .nan, .infinity] {
            let data = UITestAudioSeedTone.makeWAV(duration: invalid)
            #expect(data.count > 44, "非法时长 \(invalid) 应回退到默认时长并产生可解码音频")
        }
    }

    @Test("生成的 WAV 可被 AVAudioFile 真实解码")
    func decodesWithAVAudioFile() throws {
        let data = UITestAudioSeedTone.makeWAV(duration: 1)
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cisum-seed-tone-\(UUID().uuidString).wav")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let file = try AVAudioFile(forReading: url)
        #expect(file.length > 0, "解码器读到的采样帧数应大于 0")

        let format = file.processingFormat
        #expect(format.sampleRate == UITestAudioSeedTone.sampleRate, "采样率应与头部声明一致")
        #expect(format.channelCount == 1, "应为单声道")

        // 读取全部采样，确认不是静音占位。
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            Issue.record("无法分配 PCM 缓冲区")
            return
        }
        try file.read(into: buffer)
        guard let samples = buffer.floatChannelData?[0] else {
            Issue.record("无法读取采样通道")
            return
        }
        let peak = (0..<Int(buffer.frameLength)).reduce(Float(0)) { max($0, abs(samples[$1])) }
        #expect(peak > 0.1, "采样不应为静音，实际峰值 \(peak)")
    }

    // MARK: - Helpers

    private func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}

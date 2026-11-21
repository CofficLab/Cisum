#if os(iOS)
import Foundation
import AVFoundation
import CoreMedia
import os

/// AVAssetReader-based demuxer for HEVC streams on iOS.
///
/// `AVAssetReader` is the same parser QuickTime Player uses, so it handles `hev1`
/// (in-band parameter sets) as well as `hvc1` (out-of-band parameter sets) MP4
/// streams correctly. This is the core reason we route HEVC on iOS through
/// `AVAssetReader` instead of `AVPlayer`: AVPlayer's internal decode pipeline
/// rejects `hev1` at the pixel-format layer (-12785).
///
/// The demuxer exposes three consumers:
/// - `readVideoSampleBuffer()` — compressed HEVC `CMSampleBuffer` (NALUs) for
///   `VideoToolboxHEVCDecoder.decode(sampleBuffer:)`.
/// - `readAudioPCMBuffer()` — decoded `AVAudioPCMBuffer` from AAC for
///   `AVAudioEngineHEVCOutput.schedulePCM(_:)`.
/// - `videoFormatDescription` / `videoSize` / `duration` — used to configure
///   the `VTDecompressionSession`.
///
/// Threading: callers must invoke `read*` on the same thread that called
/// `open(url:)` (typically a background task). The reader is not thread-safe.
public final class IOSHEVCDemuxer: @unchecked Sendable {

    public enum DemuxerError: Error, CustomStringConvertible {
        case openFailed(String)
        case noVideoTrack
        case readerCreationFailed(String)
        case readerStartFailed(String)
        case readerFailed(String)

        public var description: String {
            switch self {
            case .openFailed(let m): return "AVURLAsset open failed: \(m)"
            case .noVideoTrack: return "File has no HEVC video track"
            case .readerCreationFailed(let m): return "AVAssetReader creation failed: \(m)"
            case .readerStartFailed(let m): return "AVAssetReader start failed: \(m)"
            case .readerFailed(let m): return "AVAssetReader error: \(m)"
            }
        }
    }

    /// One media packet read from the demuxer, tagged with its type and PTS.
    public enum Packet {
        case video(CMSampleBuffer)
        case audio(AVAudioPCMBuffer, ptsSeconds: Double)
        case endOfFile
    }

    private let log = Logger(subsystem: "com.coffic.cisum", category: "ios.demuxer")

    // MARK: - State

    private var asset: AVURLAsset?
    private var reader: AVAssetReader?
    private var videoOutput: AVAssetReaderTrackOutput?
    private var audioOutput: AVAssetReaderTrackOutput?
    private var audioConverter: AVAudioConverter?

    private(set) public var videoFormatDescription: CMVideoFormatDescription?
    private(set) public var videoSize: CGSize = .zero
    private(set) public var duration: TimeInterval = 0
    private(set) public var nominalFrameRate: Float = 0
    public private(set) var openedURL: URL?

    // MARK: - Lifecycle

    public init() {}

    deinit {
        close()
    }

    // MARK: - Open / Close

    /// Open the URL and prepare the reader. Throws `DemuxerError` on any failure.
    ///
    /// The video output preserves the source HEVC bitstream (no `outputSettings`)
    /// so `VTDecompressionSession` receives raw NALUs and handles codec-tag
    /// normalization (`hev1` → `hvc1`) internally.
    ///
    /// The audio output requests LinearPCM in the track's native channel layout
    /// and sample rate, ready for `AVAudioEngine` scheduling.
    public func open(url: URL) async throws {
        close()

        let asset = AVURLAsset(url: url)
        self.asset = asset
        self.openedURL = url

        // Resolve video track (HEVC required). We don't reject non-HEVC here —
        // callers can route H.264 back to AVPlayer before invoking the demuxer.
        let videoTracks: [AVAssetTrack]
        do {
            videoTracks = try await asset.loadTracks(withMediaType: .video)
        } catch {
            throw DemuxerError.openFailed("load video tracks: \(error.localizedDescription)")
        }
        guard let videoTrack = videoTracks.first else {
            throw DemuxerError.noVideoTrack
        }

        // Capture video format description + size before we hand the track to the reader.
        let formatDescs: [CMFormatDescription]
        do {
            formatDescs = try await videoTrack.load(.formatDescriptions)
        } catch {
            throw DemuxerError.openFailed("load video format descriptions: \(error.localizedDescription)")
        }
        guard let firstFormat = formatDescs.first else {
            throw DemuxerError.openFailed("video track has no format description")
        }
        videoFormatDescription = firstFormat
        let dims = CMVideoFormatDescriptionGetDimensions(firstFormat)
        videoSize = CGSize(width: Int(dims.width), height: Int(dims.height))

        if let nominal = try? await videoTrack.load(.nominalFrameRate) {
            nominalFrameRate = Float(nominal)
        }

        // Duration
        let cmDuration = try await asset.load(.duration)
        duration = cmDuration.seconds.isFinite ? cmDuration.seconds : 0

        // Create reader + outputs
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw DemuxerError.readerCreationFailed(error.localizedDescription)
        }
        self.reader = reader

        // Video: keep raw HEVC bitstream (no outputSettings) so VT can normalize hev1→hvc1.
        let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
        videoOutput.alwaysCopiesSampleData = false
        if reader.canAdd(videoOutput) {
            reader.add(videoOutput)
        } else {
            throw DemuxerError.readerCreationFailed("cannot add video output to reader")
        }
        self.videoOutput = videoOutput

        // Audio: decode to LinearPCM for AVAudioEngine.
        if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: true,
                AVLinearPCMIsBigEndianKey: false
            ]
            let audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: audioSettings)
            audioOutput.alwaysCopiesSampleData = false
            if reader.canAdd(audioOutput) {
                reader.add(audioOutput)
                self.audioOutput = audioOutput
            }
        }

        guard reader.startReading() else {
            let status = reader.status
            let errMsg = reader.error?.localizedDescription ?? "status=\(status.rawValue)"
            throw DemuxerError.readerStartFailed(errMsg)
        }

        log.info("Demux opened: \(url.lastPathComponent) video=\(Int(self.videoSize.width))x\(Int(self.videoSize.height)) fps=\(self.nominalFrameRate) duration=\(self.duration, format: .fixed(precision: 1))s")
    }

    public func close() {
        if let reader = reader, reader.status == .reading {
            reader.cancelReading()
        }
        reader = nil
        videoOutput = nil
        audioOutput = nil
        audioConverter = nil
        drainAudioUntilPTS = nil
        pendingAudioPacket = nil
        asset = nil
        videoFormatDescription = nil
        videoSize = .zero
        duration = 0
        nominalFrameRate = 0
        openedURL = nil
    }

    // MARK: - Reading

    /// Returns the next media packet. Pumps video first, then audio. EOF is signalled
    /// when the reader reports `.completed` AND both outputs are drained.
    /// Returns the next media packet. Reads one video frame, then drains all
    /// available audio frames before the next video. This naturally keeps A/V
    /// in sync without PTS comparison or caching (which can corrupt the reader).
    public func readPacket() -> Packet? {
        guard let reader = reader else { return nil }
        guard reader.status == .reading else {
            if reader.status == .failed {
                log.error("Reader failed: \(reader.error?.localizedDescription ?? "unknown")")
            }
            return nil
        }

        // Phase 1: after a video frame, keep draining audio until it is queued
        // slightly ahead of that video PTS. A fixed one-audio-per-video cadence
        // can underfeed AAC tracks whose sample buffers are shorter than a video
        // frame interval, causing AVAudioPlayerNode underruns that sound like
        // slow or stretched playback.
        if let drainUntil = drainAudioUntilPTS {
            if let pendingAudioPacket {
                if pendingAudioPacket.ptsSeconds <= drainUntil {
                    self.pendingAudioPacket = nil
                    return .audio(pendingAudioPacket.pcm, ptsSeconds: pendingAudioPacket.ptsSeconds)
                }
                drainAudioUntilPTS = nil
            } else if let ab = audioOutput?.copyNextSampleBuffer(),
                      let pcm = makePCMBuffer(from: ab) {
                let pts = CMSampleBufferGetPresentationTimeStamp(ab).seconds
                let safePTS = pts.isFinite ? pts : 0
                if safePTS <= drainUntil {
                    return .audio(pcm, ptsSeconds: safePTS)
                }
                pendingAudioPacket = (pcm, safePTS)
                drainAudioUntilPTS = nil
            }
        }

        // Phase 2: return next video frame
        if let vb = videoOutput?.copyNextSampleBuffer() {
            let pts = CMSampleBufferGetPresentationTimeStamp(vb).seconds
            let safePTS = pts.isFinite ? pts : 0
            drainAudioUntilPTS = safePTS + audioQueueLeadSeconds
            return .video(vb)
        }

        // Phase 3: no video — drain audio
        if let pendingAudioPacket {
            self.pendingAudioPacket = nil
            return .audio(pendingAudioPacket.pcm, ptsSeconds: pendingAudioPacket.ptsSeconds)
        }
        if let ab = audioOutput?.copyNextSampleBuffer(),
           let pcm = makePCMBuffer(from: ab) {
            let pts = CMSampleBufferGetPresentationTimeStamp(ab).seconds
            return .audio(pcm, ptsSeconds: pts.isFinite ? pts : 0)
        }

        // No video, no audio — check for EOF vs error.
        switch reader.status {
        case .completed:
            return .endOfFile
        case .failed:
            log.error("Reader failed mid-stream: \(reader.error?.localizedDescription ?? "unknown")")
            return nil
        default:
            return nil
        }
    }
    private var drainAudioUntilPTS: Double?
    private var pendingAudioPacket: (pcm: AVAudioPCMBuffer, ptsSeconds: Double)?
    private let audioQueueLeadSeconds = 0.50

    /// Convert an audio sample buffer (LinearPCM) into `AVAudioPCMBuffer` ready
    /// for `AVAudioEngineHEVCOutput.schedulePCM(_:)`.
    private func makePCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee

        let sampleRate = asbd?.mSampleRate ?? 48_000
        let channels = AVAudioChannelCount(asbd?.mChannelsPerFrame ?? 2)
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        ) else { return nil }

        let totalFrames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else { return nil }
        pcm.frameLength = totalFrames

        let copyStatus = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(totalFrames),
            into: pcm.mutableAudioBufferList
        )
        guard copyStatus == noErr else {
            log.error("CMSampleBufferCopyPCMDataIntoAudioBufferList failed: \(copyStatus)")
            return nil
        }
        return pcm
    }

    // MARK: - HEV1 Format Description Rebuilding
    //
    // hev1 MP4 files embed VPS/SPS/PPS parameter sets *inside* the bitstream
    // (in-band), not in the 'hvcC' box. AVAssetTrack.formatDescriptions gives us
    // a CMVideoFormatDescription but VideoToolbox sometimes cannot create a
    // decompression session from it alone (especially for hev1 on older devices).
    //
    // This helper reads the first few samples, extracts NAL units 32 (VPS),
    // 33 (SPS), and 34 (PPS), then rebuilds a complete format description using
    // CMVideoFormatDescriptionCreateFromHEVCParameterSets so VideoToolbox has
    // everything it needs to instantiate the decoder.

    /// NAL unit types relevant to HEVC format description construction.
    private enum HEVCNalType: UInt8 {
        case vps = 32
        case sps = 33
        case pps = 34
        case prefixSei = 39
        case suffixSei = 40
    }

    /// Reads up to `maxSamples` samples from the video track, extracts HEVC parameter
    /// set NAL units (VPS/SPS/PPS), and returns a rebuilt `CMVideoFormatDescription`
    /// via `CMVideoFormatDescriptionCreateFromHEVCParameterSets`.
    ///
    /// Returns `nil` if insufficient parameter sets were found.
    /// Callers should use this rebuilt description instead of the one from
    /// `AVAssetTrack.formatDescriptions` when creating a VT decompression session.
    ///
    /// Creates a temporary AVAssetReader to scan the bitstream without interfering
    /// with the main playback reader.
    public func rebuildHEV1FormatDescription(maxSamples: Int = 32) -> CMVideoFormatDescription? {
        guard let asset = asset else { return nil }
        
        // Create a temporary reader to scan for parameter sets without consuming
        // the main reader's buffer.
        guard let tempReader = try? AVAssetReader(asset: asset) else {
            log.error("Failed to create temp reader for HEV1 rebuild")
            return nil
        }
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            log.error("No video track for HEV1 rebuild")
            return nil
        }
        
        let tempOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
        tempOutput.alwaysCopiesSampleData = false
        guard tempReader.canAdd(tempOutput) else {
            log.error("Cannot add temp output for HEV1 rebuild")
            return nil
        }
        tempReader.add(tempOutput)
        
        guard tempReader.startReading() else {
            log.error("Failed to start temp reader for HEV1 rebuild")
            return nil
        }
        
        defer {
            if tempReader.status == .reading {
                tempReader.cancelReading()
            }
        }

        var vpsData: Data?
        var spsData: Data?
        var ppsData: Data?
        var vpsCount = 0
        var spsCount = 0
        var ppsCount = 0

        for sampleIndex in 0..<maxSamples {
            guard tempReader.status == .reading,
                  let sampleBuffer = tempOutput.copyNextSampleBuffer() else {
                log.info("HEV1 rebuild: stopped at sample \(sampleIndex), reader.status=\(tempReader.status.rawValue)")
                break
            }

            // In an MP4 HEVC track, NAL units use AVCC format: 4-byte big-endian
            // length prefix followed by the NAL unit payload.
            guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }

            var lengthAtOffset = 0
            var totalLength = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            let status = CMBlockBufferGetDataPointer(
                dataBuffer,
                atOffset: 0,
                lengthAtOffsetOut: &lengthAtOffset,
                totalLengthOut: &totalLength,
                dataPointerOut: &dataPointer
            )
            guard status == kCMBlockBufferNoErr, let base = dataPointer else { continue }

            let basePtr = UnsafeRawPointer(base)
            var offset = 0

            while offset + 4 <= totalLength {
                // Read 4-byte big-endian NAL unit length.
                // Use memcpy to avoid misaligned pointer access on real devices.
                var nalLengthBytes: UInt32 = 0
                withUnsafeMutableBytes(of: &nalLengthBytes) { dest in
                    memcpy(dest.baseAddress!, basePtr.advanced(by: offset), 4)
                }
                let nalLength = UInt32(bigEndian: nalLengthBytes)
                guard nalLength > 0, offset + 4 + Int(nalLength) <= totalLength else { break }

                let nalDataPtr = basePtr.advanced(by: offset + 4)
                let nalTypeByte = nalDataPtr.load(as: UInt8.self)
                // HEVC NAL header (first byte): 1 bit forbidden_zero_bit + 6 bits nal_unit_type + 1 bit nuh_layer_id_high
                // Extract the 6-bit NAL unit type from bits 1-6 (counting from MSB)
                let nalType = (nalTypeByte >> 1) & 0x3F

                // Extract the NAL unit payload. CMVideoFormatDescriptionCreateFromHEVCParameterSets
                // requires the COMPLETE NAL unit — the 2-byte HEVC NAL header followed by the RBSP
                // payload — exactly as it appears in the bitstream (no start code, no length prefix).
                // Stripping the NAL header (passing only RBSP) causes -12712 (kVTParameterErr).
                // See: developer.apple.com/documentation/coremedia/cmvideoformatdescriptioncreatefromhevcparametersets
                let nalPayload = Data(bytes: nalDataPtr, count: Int(nalLength))

                if offset < 200 {  // Log first few NAL units for debugging
                    log.debug("NAL @offset=\(offset): type=\(nalType) len=\(nalLength) payload=\(nalPayload.count)B")
                }

                switch nalType {
                case HEVCNalType.vps.rawValue:
                    if vpsData == nil { vpsData = nalPayload }
                    vpsCount += 1
                case HEVCNalType.sps.rawValue:
                    if spsData == nil { spsData = nalPayload }
                    spsCount += 1
                case HEVCNalType.pps.rawValue:
                    if ppsData == nil { ppsData = nalPayload }
                    ppsCount += 1
                default:
                    break
                }

                offset += 4 + Int(nalLength)
            }

            // Stop early once we have all three parameter sets.
            if vpsData != nil && spsData != nil && ppsData != nil {
                break
            }
        }

        // Need at least one of each VPS/SPS/PPS.
        guard let vps = vpsData, let sps = spsData, let pps = ppsData else {
            log.error("HEV1 rebuild failed: vps=\(vpsData != nil)/\(vpsCount) sps=\(spsData != nil)/\(spsCount) pps=\(ppsData != nil)/\(ppsCount)")
            return nil
        }

        log.info("HEV1 rebuild: collected vps=\(vps.count)B sps=\(sps.count)B pps=\(pps.count)B (\(vpsCount)/\(spsCount)/\(ppsCount) total units)")

        // Build CMVideoFormatDescription from parameter sets.
        // We must ensure Data objects (vps/sps/pps) stay alive while we call the API.
        var formatDesc: CMVideoFormatDescription?
        let result: OSStatus = vps.withUnsafeBytes { vpsBytes in
            sps.withUnsafeBytes { spsBytes in
                pps.withUnsafeBytes { ppsBytes in
                    let paramSetPointers: [UnsafePointer<UInt8>] = [
                        vpsBytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        spsBytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        ppsBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    ]
                    let paramSetSizes: [Int] = [vps.count, sps.count, pps.count]
                    
                    return paramSetPointers.withUnsafeBufferPointer { pointersBuffer in
                        paramSetSizes.withUnsafeBufferPointer { sizesBuffer in
                            CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                                allocator: kCFAllocatorDefault,
                                parameterSetCount: 3,
                                parameterSetPointers: pointersBuffer.baseAddress!,
                                parameterSetSizes: sizesBuffer.baseAddress!,
                                nalUnitHeaderLength: 4,
                                extensions: nil,
                                formatDescriptionOut: &formatDesc
                            )
                        }
                    }
                }
            }
        }

        guard result == noErr, let desc = formatDesc else {
            log.error("CMVideoFormatDescriptionCreateFromHEVCParameterSets failed: \(result)")
            return nil
        }

        log.info("HEV1 CMVideoFormatDescription rebuilt successfully")
        return desc
    }
}
#endif

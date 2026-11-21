#if os(iOS)
import Foundation
import AVFoundation
import CoreMedia
import CoreVideo
import VideoToolbox
import os
import MagicKit

/// VideoToolbox HEVC decoder.
///
/// Wraps `VTDecompressionSession` for hardware-accelerated HEVC decoding.
/// Sample buffers come from `AVAssetReader` and decoded `CVPixelBuffer` outputs
/// are passed to a callback (on an internal decompression queue).
public final class VideoToolboxHEVCDecoder: @unchecked Sendable, SuperLog {
    nonisolated public static let emoji = "🎬"
    nonisolated public static let author = "VideoToolboxHEVCDecoder"
    nonisolated public static let verbose = false
    nonisolated public static let logger = Logger(subsystem: "com.coffic.cisum", category: "vt.hevc")

    private let log = Logger(subsystem: "com.coffic.cisum", category: "vt.hevc")
    private let decompressionQueue = DispatchQueue(label: "com.coffic.cisum.vt.hevc", qos: .userInitiated)

    private(set) var session: VTDecompressionSession?
    private var outputCallback: ((CVPixelBuffer, TimeInterval) -> Void)?

    /// The format description the session was created with. Kept so `decode`
    /// can detect hev1→hvc1 mismatches and rebuild incoming sample buffers
    /// (stripping in-band parameter sets) to match what the session expects.
    private var sessionFormatDescription: CMVideoFormatDescription?

    /// Maximum number of decode requests that may be in flight (submitted but
    /// whose outputHandler has not yet returned). Caps the burst rate into the
    /// hardware decoder: without backpressure the playback loop floods VT with
    /// the entire stream at once, every outputHandler returns
    /// `kVTPixelTransferNotAvailableNow` (-12916) with a nil imageBuffer, and no
    /// frame is ever decoded. This semaphore turns the fire-and-forget loop into
    /// a bounded pipeline (the IINA/VLC/mpv pattern for async VT decoding).
    private static let maxInFlight = 4
    private let inFlightSemaphore = DispatchSemaphore(value: maxInFlight)

    public init() {}

    deinit {
        invalidate()
    }

    public func invalidate() {
        // Drain in-flight decode callbacks so their `signal()` calls balance the
        // `wait()` calls made in `decode()`. VTDecompressionSession's contract:
        // WaitForAsynchronousFrames blocks until every pending async frame's
        // callback has fired, which means every outstanding semaphore unit is
        // returned. Order matters: wait BEFORE invalidate, capture the session
        // locally because we nil it below.
        if let session = session {
            VTDecompressionSessionWaitForAsynchronousFrames(session)
            VTDecompressionSessionInvalidate(session)
        }
        session = nil
        sessionFormatDescription = nil
        outputCallback = nil
    }

    /// Create a new `VTDecompressionSession` configured for HEVC.
    /// The callback is invoked from VideoToolbox's internal queue with each decoded frame.
    ///
    /// ## Hardware vs Software Decoding
    ///
    /// The decoder attempts two phases, each with a small retry budget:
    ///
    /// 1. **Default (hardware-preferred)** — pass `nil` for the decoder
    ///    specification so VideoToolbox selects its preferred backend (usually
    ///    hardware). A few retries cover the case of a transiently-busy shared
    ///    hardware decoder (`kVTVideoDecoderNotAvailableNow`, -12906).
    ///
    /// 2. **Software fallback** — if the default path keeps returning -12906,
    ///    explicitly pass `EnableHardwareAcceleratedVideoDecoder=false` to force
    ///    the CoreVideo software decoder. This is also retried, because the
    ///    first software attempt can race with session activation on iOS.
    ///
    /// Persistent -12906 across BOTH phases usually indicates the `AVAudioSession`
    /// is not active (app not seen as a foreground media session) or the format
    /// description is malformed — neither is helped by more retries, so the
    /// budgets here are deliberately small (no more than ~2s total).
    ///
    /// If both phases fail, `VideoToolboxDecoderError.sessionCreationFailed`
    /// is thrown. Callers (e.g. `IOSHEVCPlayer`) can catch this and report it to
    /// `iOSPlaybackPluginImpl` so the plugin falls back to `AVPlayer`.
    public func createSession(
        formatDescription: CMVideoFormatDescription,
        hardwareOnly: Bool = true,
        callback: @escaping @Sendable (CVPixelBuffer, TimeInterval) -> Void
    ) async throws {
        invalidate()
        self.outputCallback = callback

        let dims = CMVideoFormatDescriptionGetDimensions(formatDescription)
        let subtype = CMFormatDescriptionGetMediaSubType(formatDescription)
        let fourCC = String(format: "%c%c%c%c",
                            (subtype >> 24) & 0xFF, (subtype >> 16) & 0xFF,
                            (subtype >> 8) & 0xFF, subtype & 0xFF)
        log.info("createSession: format \(fourCC) \(Int(dims.width))x\(Int(dims.height))")

        // Destination pixel buffer attributes: bi-planar YUV (NV12), Metal-compatible
        let destinationAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()
        ]

        var sessionRef: VTDecompressionSession?
        var status: OSStatus = -12906  // kVTVideoDecoderNotAvailableNow sentinel
        var usedSoftwareFallback = false

        // Phase 1: default decoder selection (hardware-preferred). Small retry
        // budget — enough for a transiently busy decoder, not enough to stall
        // the UI for seconds when the failure is permanent.
        let phase1Attempts = 5
        for attempt in 0..<phase1Attempts {
            sessionRef = nil
            status = VTDecompressionSessionCreate(
                allocator: kCFAllocatorDefault,
                formatDescription: formatDescription,
                decoderSpecification: nil,
                imageBufferAttributes: destinationAttributes as CFDictionary,
                outputCallback: nil,
                decompressionSessionOut: &sessionRef
            )
            if status == noErr {
                log.info("VT session created (default) on attempt \(attempt + 1)")
                break
            }
            if status != -12906 { break }  // Non-transient: don't retry
            log.info("VT create attempt \(attempt + 1)/\(phase1Attempts): kVTVideoDecoderNotAvailableNow, retrying...")
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        // Phase 2: explicit software (CoreVideo) decoder. Retry a few times so a
        // slow AVAudioSession activation doesn't permanently defeat software too.
        if status != noErr && !hardwareOnly {
            log.info("Default VT session unavailable (status=\(status)); attempting software (CoreVideo) decoder...")
            let softwareSpec: [String: Any] = [
                "EnableHardwareAcceleratedVideoDecoder" as String: false as Any
            ]
            let phase2Attempts = 5
            for attempt in 0..<phase2Attempts {
                sessionRef = nil
                status = VTDecompressionSessionCreate(
                    allocator: kCFAllocatorDefault,
                    formatDescription: formatDescription,
                    decoderSpecification: softwareSpec as CFDictionary,
                    imageBufferAttributes: destinationAttributes as CFDictionary,
                    outputCallback: nil,
                    decompressionSessionOut: &sessionRef
                )
                if status == noErr {
                    usedSoftwareFallback = true
                    log.info("Software CoreVideo HEVC decoder session created on attempt \(attempt + 1)")
                    break
                }
                if status != -12906 { break }  // Non-transient: don't retry
                log.info("Software VT create attempt \(attempt + 1)/\(phase2Attempts): kVTVideoDecoderNotAvailableNow, retrying...")
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            if status != noErr {
                log.error("Software decoder also failed: status=\(status)")
            }
        }

        guard status == noErr, let newSession = sessionRef else {
            let errName: String
            switch status {
            case -12909: errName = "kVTParameterErr"
            case -12911: errName = "kVTAllocationFailed"
            case -12910: errName = "kVTFormatUnsupported"
            case -12906: errName = "kVTVideoDecoderNotAvailableNow"
            case -12905: errName = "kVTVideoDecoderBadData"
            case -12712: errName = "kVTParameterErr(-12712)"
            case -50: errName = "paramErr"
            default: errName = "unknown"
            }
            if Self.verbose {
                Self.logger.info("\(Self.t)=== HEVC VTDecompressionSessionCreate FAILED: status=\(status) (\(errName)) format=\(fourCC) \(Int(dims.width))x\(Int(dims.height)) ===")
            }
            log.error("VTDecompressionSessionCreate failed: status=\(status) (\(errName)) format=\(fourCC) \(Int(dims.width))x\(Int(dims.height))")
            throw VideoToolboxDecoderError.sessionCreationFailed(status)
        }
        self.session = newSession
        self.sessionFormatDescription = formatDescription
        if usedSoftwareFallback {
            log.info("VTDecompressionSession created for HEVC (software/CoreVideo fallback)")
        } else {
            log.info("VTDecompressionSession created for HEVC (hardware)")
        }
    }

    /// Submit a sample buffer for decoding.
    ///
    /// Blocks (via the in-flight semaphore) if `maxInFlight` requests are already
    /// pending, providing backpressure against the caller's read loop. This is
    /// essential: `VTDecompressionSessionDecodeFrame` is asynchronous, so without
    /// throttling the caller floods the hardware decoder and every callback
    /// returns `kVTPixelTransferNotAvailableNow` (-12916) with a nil imageBuffer.
    public func decode(sampleBuffer: CMSampleBuffer,
                       decodeFlags: VTDecodeFrameFlags,
                       decodeInfoFlags: VTDecodeInfoFlags,
                       ptsSeconds: TimeInterval) {
        guard let session = session else { return }

        // Acquire an in-flight slot. Blocks the caller (the playback loop) when
        // the pipeline is full, naturally throttling it to the decoder's rate.
        inFlightSemaphore.wait()

        // Normalize the sample buffer so its format description matches the
        // session. hev1 sources carry in-band VPS/SPS/PPS in every sample; a
        // session built on an hvc1 (out-of-band) format description rejects
        // them with kVTFormatDescriptionChangeNotSupportedErr (-12916). Stripping
        // the non-VCL NALs and re-tagging with the session's format desc makes
        // the sample look like hvc1, which is exactly what the session expects.
        let bufferToDecode = normalizedSampleBuffer(for: sampleBuffer) ?? sampleBuffer

        var infoFlags = decodeInfoFlags
        let status = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: bufferToDecode,
            flags: decodeFlags,
            infoFlagsOut: &infoFlags,
            outputHandler: { [weak self] status, _, imageBuffer, _, _ in
                // ALWAYS release the slot — on success AND failure. A missing
                // signal() here would deadlock the playback loop once the quota
                // is exhausted by failing frames.
                defer { self?.inFlightSemaphore.signal() }
                guard status == noErr, let pixelBuffer = imageBuffer else {
                    self?.recordDecodeFailure(status: status, hasImage: imageBuffer != nil)
                    return
                }
                self?.recordDecodeSuccess()
                self?.outputCallback?(pixelBuffer, ptsSeconds)
            }
        )
        if status != noErr {
            // The synchronous submit itself failed (e.g. session invalidated).
            // The outputHandler will NOT fire for this request, so release the
            // slot we acquired above to avoid leaking a quota unit.
            inFlightSemaphore.signal()
            log.error("VTDecompressionSessionDecodeFrame failed: \(status)")
        }
    }

    // MARK: - Sample buffer normalization (hev1 → hvc1)

    /// HEVC NAL unit types whose payloads are parameter sets (non-VCL). These
    /// are what `hev1` embeds in-band and `hvc1` expects only in the format
    /// description. Stripping them from each sample makes an hev1 sample look
    /// like an hvc1 sample.
    private static let hevcParameterSetNalTypes: Set<UInt8> = [32, 33, 34]  // VPS, SPS, PPS

    /// If the sample buffer's format description differs from the session's
    /// (the hev1→hvc1 case), rebuild the sample buffer without in-band VPS/SPS/PPS
    /// NALs, re-tagged with the session's format description. Returns `nil` when
    /// no normalization is needed (fast path: same format description) or when
    /// the rebuild fails (caller falls back to the original buffer).
    private func normalizedSampleBuffer(for sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        guard let sessionDesc = sessionFormatDescription,
              let sampleDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return nil
        }
        let sessionSubtype = CMFormatDescriptionGetMediaSubType(sessionDesc)
        let sampleSubtype = CMFormatDescriptionGetMediaSubType(sampleDesc)

        // One-shot diagnostic: log the subtype relationship on first invocation
        // so we can see whether sample buffers are hev1 (need stripping) or
        // hvc1 (already match the session).
        logSampleFormatOnce(sessionSubtype: sessionSubtype, sampleSubtype: sampleSubtype)

        // Fast path: same codec tag — nothing to do.
        if sessionSubtype == sampleSubtype { return nil }

        // Slow path: extract the NAL payload, drop parameter-set NALs, rebuild.
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }

        var lengthAtOffset = 0
        var totalLength = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let pointerStatus = CMBlockBufferGetDataPointer(
            blockBuffer, atOffset: 0,
            lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        )
        guard pointerStatus == kCMBlockBufferNoErr, let base = dataPointer else { return nil }

        let basePtr = UnsafeRawPointer(base)
        var offset = 0
        // Pre-allocate with the source size: the filtered buffer is never larger
        // than the original (we only drop NALs).
        var rebuiltBytes = Data(capacity: totalLength)
        var strippedCount = 0

        while offset + 4 <= totalLength {
            var nalLengthRaw: UInt32 = 0
            withUnsafeMutableBytes(of: &nalLengthRaw) { dest in
                memcpy(dest.baseAddress!, basePtr.advanced(by: offset), 4)
            }
            let nalLength = UInt32(bigEndian: nalLengthRaw)
            guard nalLength > 0, offset + 4 + Int(nalLength) <= totalLength else { break }

            let nalStart = offset + 4
            let nalTypeByte = basePtr.advanced(by: nalStart).load(as: UInt8.self)
            let nalType = (nalTypeByte >> 1) & 0x3F

            if Self.hevcParameterSetNalTypes.contains(nalType) {
                // Drop VPS/SPS/PPS — the session's hvc1 desc already has them.
                strippedCount += 1
            } else {
                // Keep this NAL: re-emit its 4-byte length prefix + payload.
                let nalTotal = 4 + Int(nalLength)
                rebuiltBytes.append(basePtr.advanced(by: offset).assumingMemoryBound(to: UInt8.self), count: nalTotal)
            }
            offset = nalStart + Int(nalLength)
        }

        // Rebuild whenever we have any slice NAL to keep, EVEN if no parameter
        // sets were stripped. The key purpose of rebuilding is to re-tag the
        // sample with the session's hvc1 format description — non-keyframes
        // (P/B frames) carry no parameter sets but their sample buffer is still
        // tagged hev1, which the hvc1 session rejects with -12916. Returning nil
        // here would fall back to the original hev1 buffer and fail.
        guard !rebuiltBytes.isEmpty else { return nil }

        // Build a new block buffer owning a copy of the filtered bytes.
        // We let CoreMedia allocate the backing store (memoryBlock: nil) and
        // force immediate allocation with kCMBlockBufferAssureMemoryNowFlag —
        // without it the memory is lazily allocated and GetDataPointer returns
        // -12707 (kCMBlockBufferStructureAllocationFailedErr). CMBlockBufferFillDataBytes
        // has a broken Swift import (its `with` arg is a single CChar, not a
        // pointer), so we memcpy into the allocated pointer directly.
        let rebuiltCount = rebuiltBytes.count
        var tempBlock: CMBlockBuffer?
        let createStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: rebuiltCount,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: rebuiltCount,
            flags: kCMBlockBufferAssureMemoryNowFlag,
            blockBufferOut: &tempBlock
        )
        guard createStatus == kCMBlockBufferNoErr, let temp = tempBlock else {
            log.error("normalizedSampleBuffer: block buffer create failed: \(createStatus)")
            return nil
        }
        // Copy the filtered bytes into the freshly-allocated block buffer.
        var bbLen = 0
        var bbTotal = 0
        var bbPtr: UnsafeMutablePointer<Int8>?
        let ptrStatus = CMBlockBufferGetDataPointer(
            temp, atOffset: 0,
            lengthAtOffsetOut: &bbLen,
            totalLengthOut: &bbTotal,
            dataPointerOut: &bbPtr
        )
        guard ptrStatus == kCMBlockBufferNoErr, let dst = bbPtr, bbTotal >= rebuiltCount else {
            log.error("normalizedSampleBuffer: block buffer pointer failed: \(ptrStatus)")
            return nil
        }
        rebuiltBytes.withUnsafeBytes { rawBuf in
            if let src = rawBuf.baseAddress {
                memcpy(dst, src, rebuiltCount)
            }
        }

        // Rebuild the sample buffer preserving timing/PTS, using the session's
        // format description so VT sees a matching codec tag.
        var sampleTiming = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(sampleBuffer),
            presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            decodeTimeStamp: CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
        )
        var sampleSize = rebuiltCount
        var formatDescRef: CMVideoFormatDescription? = sessionDesc
        var newSampleBuffer: CMSampleBuffer?
        let sampleStatus: OSStatus = withUnsafeMutablePointer(to: &sampleTiming) { timingPtr in
            withUnsafeMutablePointer(to: &sampleSize) { sizePtr in
                CMSampleBufferCreateReady(
                    allocator: kCFAllocatorDefault,
                    dataBuffer: temp,
                    formatDescription: formatDescRef,
                    sampleCount: 1,
                    sampleTimingEntryCount: 1,
                    sampleTimingArray: timingPtr,
                    sampleSizeEntryCount: 1,
                    sampleSizeArray: sizePtr,
                    sampleBufferOut: &newSampleBuffer
                )
            }
        }
        if sampleStatus != noErr {
            log.error("normalizedSampleBuffer: sample buffer rebuild failed: \(sampleStatus) (stripped \(strippedCount) param NALs)")
            return nil
        }
        return newSampleBuffer
    }

    // MARK: - Decode stats (diagnostics)

    private var decodeSuccessCount = 0
    private var decodeFailCount = 0
    private var lastFailStatus: OSStatus = 0
    private let statsLock = NSLock()

    private func recordDecodeSuccess() {
        statsLock.lock()
        decodeSuccessCount += 1
        let s = decodeSuccessCount
        statsLock.unlock()
        if s == 1 || s % 60 == 0 {
            log.info("decode OK frame #\(s)")
        }
    }

    private func recordDecodeFailure(status: OSStatus, hasImage: Bool) {
        statsLock.lock()
        decodeFailCount += 1
        let n = decodeFailCount
        lastFailStatus = status
        statsLock.unlock()
        if n == 1 {
            log.error("decode outputHandler FIRST failure: status=\(status) hasImage=\(hasImage)")
        } else if n <= 5 {
            log.error("decode outputHandler failure #\(n): status=\(status)")
        }
    }

    private var loggedSampleFormat = false

    private func logSampleFormatOnce(sessionSubtype: FourCharCode, sampleSubtype: FourCharCode) {
        guard !loggedSampleFormat else { return }
        loggedSampleFormat = true
        let s = fourCCString(sessionSubtype)
        let sm = fourCCString(sampleSubtype)
        log.info("format check: session=\(s) sample=\(sm) match=\(sessionSubtype == sampleSubtype)")
    }

    private func fourCCString(_ value: FourCharCode) -> String {
        String(format: "%c%c%c%c",
               (value >> 24) & 0xFF, (value >> 16) & 0xFF,
               (value >> 8) & 0xFF, value & 0xFF)
    }

    /// Flush any pending frames.
    public func flush() {
        guard let session = session else { return }
        VTDecompressionSessionWaitForAsynchronousFrames(session)
    }
}

public enum VideoToolboxDecoderError: Error, CustomStringConvertible {
    case sessionCreationFailed(OSStatus)
    case decodeFailed(String)

    public var description: String {
        switch self {
        case .sessionCreationFailed(let s): return "VTDecompressionSession creation failed (\(s))"
        case .decodeFailed(let m): return "VideoToolbox decode failed: \(m)"
        }
    }
}
#endif

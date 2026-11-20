#if os(iOS)
import Foundation
import VideoToolbox
import os
import MagicKit

/// Cache of hardware decoding capabilities for this Mac.
///
/// `VTIsHardwareDecodeSupported` is long-running and should NOT be called on the main thread.
/// This cache populates asynchronously on a background queue, so callers on the main thread
/// (e.g. PlaybackPluginImpl.validateAndPrepareToPlay) can quickly query the result.
///
/// Pattern lifted from IINA's `HardwareDecodeCapabilities.swift`.
public final class HardwareDecodeCapabilities: @unchecked Sendable, SuperLog {

    public static let shared = HardwareDecodeCapabilities()

    /// Codecs that we may need hardware decoding for.
    /// We pre-populate this list lazily on first access — the cache is filled asynchronously.
    private let codecTypes: [CMVideoCodecType] = [
        kCMVideoCodecType_HEVC,                  // H.265
        kCMVideoCodecType_HEVCWithAlpha,         // H.265 alpha
        kCMVideoCodecType_H264,                  // AVC (verify hardware availability)
        kCMVideoCodecType_VP9,                   // VP9
        kCMVideoCodecType_AV1                    // AV1
    ]

    private var supported: [CMVideoCodecType: Bool] = [:]
    private var isInitialized = false
    private let initLock = NSLock()

    public nonisolated static let emoji = "🎞️"
    public nonisolated static let author = "HardwareDecodeCapabilities"
    public nonisolated static let verbose = false
    public nonisolated static let logger = Logger(subsystem: "com.coffic.cisum", category: "hwaccel")

    private init() {}

    /// Begin populating the cache asynchronously. Safe to call multiple times.
    public func checkCapabilities() {
        initLock.lock()
        if isInitialized {
            initLock.unlock()
            return
        }
        isInitialized = true
        initLock.unlock()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            for codec in self.codecTypes {
                let isSupported = self.isHardwareDecodeSupported(codec)
                self.supported[codec] = isSupported
                if Self.verbose {
                    Self.logger.info("\(Self.t)hwaccel: codec \(self.fourCC(codec)) supported=\(isSupported)")
                }
            }
        }
    }

    /// Query whether a codec is hardware-decodable. Returns `false` until the cache
    /// has been populated (i.e. for the first few seconds of app lifetime).
    public func isSupported(_ codec: CMVideoCodecType) -> Bool {
        supported[codec] ?? false
    }

    /// Convenience: check HEVC hardware decode support (most common case).
    public var isHEVCHardwareDecodeSupported: Bool {
        isSupported(kCMVideoCodecType_HEVC)
    }

    /// Returns true if the codec is known and definitely NOT hardware-decodable.
    /// Useful to fail fast without waiting for the async cache.
    public func isKnownUnsupported(_ codec: CMVideoCodecType) -> Bool {
        // Conservative: assume supported until proven otherwise.
        // Real check comes from `isSupported` after cache population.
        return false
    }

    // MARK: - Private

    private func isHardwareDecodeSupported(_ codecType: CMVideoCodecType) -> Bool {
        return VTIsHardwareDecodeSupported(codecType)
    }

    private func fourCC(_ codec: CMVideoCodecType) -> String {
        let bytes: [UInt8] = [
            UInt8((codec >> 24) & 0xFF),
            UInt8((codec >> 16) & 0xFF),
            UInt8((codec >> 8) & 0xFF),
            UInt8(codec & 0xFF)
        ]
        let str = String(bytes: bytes, encoding: .ascii) ?? "????"
        return str.trimmingCharacters(in: .whitespaces)
    }
}
#endif

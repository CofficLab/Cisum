#if os(iOS)
import Foundation
import AVFoundation
import Combine
import CoreMedia
import CoreVideo
import VideoToolbox
import os
import QuartzCore

/// iOS-only HEVC playback orchestrator.
///
/// Composes `IOSHEVCDemuxer` + `VideoToolboxHEVCDecoder` + `AVAudioEngineHEVCOutput`
/// into a single playable object. Video frames are surfaced to the host
/// application via `onVideoFrame: (CVPixelBuffer, CMTime) -> Void`, which the
/// `IOSHEVCVideoView` consumes to feed an `AVSampleBufferDisplayLayer`.
///
/// This player exists specifically because iOS AVPlayer rejects `hev1`-tagged
/// HEVC streams at the pixel-format layer (`err=-12785`,
/// `kCMSampleBufferError_TransferDestinationDoesNotSupportPixelFormat`).
/// Driving `VTDecompressionSession` ourselves lets us accept `hev1` bitstreams
/// — the same approach IINA takes on macOS.
@MainActor
public final class IOSHEVCPlayer: ObservableObject {

    // MARK: - Public State

    @Published public private(set) var currentItemURL: URL?
    @Published public private(set) var playerState: HEVCDecoderPlaybackState = .idle
    @Published public private(set) var playerError: String?
    @Published public private(set) var isPlaying = false
    @Published public private(set) var currentTime: TimeInterval = 0
    @Published public private(set) var duration: TimeInterval = 0
    @Published public private(set) var videoSize: CGSize = .zero
    @Published public private(set) var nominalFrameRate: Float = 0

    /// Delivered on the main thread for each decoded video frame. The pixel
    /// buffer is owned by VideoToolbox and remains valid until the next
    /// decode call (typically a few ms). Wrap it in a `CMSampleBuffer` if you
    /// need to retain it.
    public var onVideoFrame: ((CVPixelBuffer, CMTime) -> Void)?

    /// Called once when the decoder session is ready, with the video
    /// format description. Consumers should use this to pre-create any
    /// downstream renderers keyed on the format (e.g. AVSampleBufferDisplayLayer).
    public var onSessionReady: ((CMVideoFormatDescription) -> Void)?

    /// Fired when the decoder session could not be created and the VT path
    /// should be abandoned. Callers can catch this to fallback to AVPlayer.
    public var onDecoderUnavailable: ((Error) -> Void)?

    // MARK: - Internals

    private let log = Logger(subsystem: "com.coffic.cisum", category: "ios.hevc.player")
    private let demuxer = IOSHEVCDemuxer()
    private let decoder = VideoToolboxHEVCDecoder()
    private let audioOutput = AVAudioEngineHEVCOutput()
    private let clock = AVSynchronizedClock()

    private var playbackTask: Task<Void, Never>?
    private var pausedAtMediaTime: Double = 0
    private var playbackGeneration = 0
    private var lateVideoFrameDropCount = 0

    public init() {
        HardwareDecodeCapabilities.shared.checkCapabilities()
    }

    // Note: no deinit cleanup here. IOSHEVCPlayer is @MainActor; its deinit
    // would be nonisolated and thus cannot safely touch the player, decoder,
    // or audio output. Callers must invoke `stop()` explicitly before
    // releasing the player. The plugin (iOSPlaybackPluginImpl) does this in
    // its own teardown path.

    // MARK: - Playback Controls

    public func play(url: URL) {
        log.info("IOSHEVCPlayer play: \(url.lastPathComponent)")
        stop()
        playbackGeneration += 1

        currentItemURL = url
        playerError = nil
        playerState = .loading
        isPlaying = false
        currentTime = 0
        pausedAtMediaTime = 0
        lateVideoFrameDropCount = 0

        // Run the decode loop on a background thread (Task.detached) so the
        // synchronous demux/decode calls — and the in-flight semaphore wait
        // inside VideoToolboxHEVCDecoder.decode — do NOT block the MainActor.
        // Blocking the main thread starves AVSampleBufferDisplayLayer's render
        // run loop, so the first frame enqueues but never displays (black screen).
        // UI state updates hop back to MainActor inside runPlaybackLoop.
        playbackTask = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.runPlaybackLoop(url: url)
        }
    }

    public func pause() {
        guard isPlaying else { return }
        pausedAtMediaTime = clock.currentMediaTime
        clock.pauseAnchor(toMediaTime: pausedAtMediaTime)
        audioOutput.pause()
        isPlaying = false
        playerState = .paused
        log.info("IOSHEVCPlayer paused at \(self.pausedAtMediaTime, format: .fixed(precision: 3))s")
    }

    public func resume() {
        guard playerState == .paused else { return }
        clock.start(atMediaTime: pausedAtMediaTime)
        audioOutput.resume()
        isPlaying = true
        playerState = .playing
        log.info("IOSHEVCPlayer resumed from \(self.pausedAtMediaTime, format: .fixed(precision: 3))s")
    }

    public func stop() {
        playbackGeneration += 1
        playbackTask?.cancel()
        playbackTask = nil
        decoder.invalidate()
        audioOutput.stop()
        clock.reset()
        currentItemURL = nil
        currentTime = 0
        duration = 0
        videoSize = .zero
        isPlaying = false
        pausedAtMediaTime = 0
        playerState = .idle
        playerError = nil
    }

    /// Seek to a target time in seconds. Implemented by tearing down the
    /// current reader + decoder and rebuilding them at the requested offset.
    /// Note: this is coarse — we don't pre-roll to the exact frame. Adequate
    /// for scrubbing; for sample-accurate seeking we'd need keyframe-aware
    /// pre-buffering.
    public func seek(to time: TimeInterval) {
        guard let url = currentItemURL else { return }
        log.info("IOSHEVCPlayer seek to \(time, format: .fixed(precision: 2))s")
        playbackTask?.cancel()
        playbackTask = nil
        playbackGeneration += 1
        decoder.invalidate()
        audioOutput.stop()
        clock.reset()

        playbackTask = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.runPlaybackLoop(url: url, seekTo: time)
        }
    }

    // MARK: - Playback Loop

    private nonisolated func runPlaybackLoop(url: URL, seekTo targetTime: TimeInterval = 0) async {
        do {
            try await demuxer.open(url: url)
            await MainActor.run {
                self.duration = demuxer.duration
                self.videoSize = demuxer.videoSize
                self.nominalFrameRate = demuxer.nominalFrameRate
            }

            // For 'hev1' MP4 files the format description from AVAssetTrack may lack
            // sufficient HEVC parameter set information for VideoToolbox to create
            // a decompression session. Try the original description first; if VT fails,
            // rebuild it by extracting VPS/SPS/PPS NAL units directly from the bitstream.
            var formatDesc = demuxer.videoFormatDescription
            if formatDesc == nil {
                throw IOSHEVCPlayerError.noVideoFormat
            }

            var vtSessionCreated = false
            var lastVTError: Error?
            var rebuiltDesc: CMVideoFormatDescription?
            let generation = await MainActor.run { self.playbackGeneration }

            // Attempt 1: original format description (works for 'hvc1' and some 'hev1' files).
            do {
                try await decoder.createSession(formatDescription: formatDesc!, hardwareOnly: false) { [weak self] pixelBuffer, ptsSeconds in
                    nonisolated(unsafe) let pb = pixelBuffer
                    self?.scheduleVideoFrame(pixelBuffer: pb, ptsSeconds: ptsSeconds, generation: generation)
                }
                vtSessionCreated = true
            } catch {
                log.info("VT session with original format desc failed (\(error)); attempting HEV1 rebuild...")
                lastVTError = error

                // Attempt 2: rebuild the format description from in-band VPS/SPS/PPS NAL units.
                rebuiltDesc = demuxer.rebuildHEV1FormatDescription()
                if let rebuiltDesc {
                    log.info("Retrying VT session with rebuilt HEV1 format description...")
                    do {
                        try await decoder.createSession(formatDescription: rebuiltDesc, hardwareOnly: false) { [weak self] pixelBuffer, ptsSeconds in
                            nonisolated(unsafe) let pb = pixelBuffer
                            self?.scheduleVideoFrame(pixelBuffer: pb, ptsSeconds: ptsSeconds, generation: generation)
                        }
                        vtSessionCreated = true
                    } catch {
                        log.error("VT session with rebuilt HEV1 format desc also failed: \(error)")
                        lastVTError = error
                    }
                } else {
                    log.error("HEV1 format description rebuild failed")
                }
            }

            if !vtSessionCreated {
                log.error("VT decoder unavailable after original+rebuilt attempts")
                await MainActor.run { [weak self] in
                    self?.onDecoderUnavailable?(lastVTError ?? IOSHEVCPlayerError.vtDecoderUnavailable)
                }
                return
            }

            // Surface the format description so renderers can prepare.
            // Prefer the rebuilt description if we used it; otherwise the original.
            guard let descToUse = rebuiltDesc ?? formatDesc else {
                log.error("No format description available for onSessionReady callback")
                await MainActor.run { [weak self] in
                    self?.onDecoderUnavailable?(IOSHEVCPlayerError.noVideoFormat)
                }
                return
            }
            await MainActor.run { [weak self] in
                self?.onSessionReady?(descToUse)
            }

            // If seeking, advance the demuxer until we cross the target PTS,
            // then start playback from there.
            if targetTime > 0 {
                var skippedPackets = 0
                while !Task.isCancelled {
                    guard let packet = demuxer.readPacket() else { break }
                    switch packet {
                    case .video(let sampleBuffer):
                        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
                        if pts >= targetTime {
                            let safePTS = pts.isFinite ? pts : targetTime
                            await MainActor.run {
                                self.clock.start(atMediaTime: safePTS)
                                self.currentTime = safePTS
                            }

                            // Roll the decoder: flush & resubmit this frame after
                            // anchoring playback to the frame PTS.
                            decoder.decode(
                                sampleBuffer: sampleBuffer,
                                decodeFlags: [],
                                decodeInfoFlags: [],
                                ptsSeconds: safePTS
                            )
                            skippedPackets += 1
                            await beginPlayback()
                            return
                        }
                        skippedPackets += 1
                    case .audio(let pcm, let pts):
                        // Drop audio before seek target.
                        _ = pcm; _ = pts
                    case .endOfFile:
                        break
                    }
                    if skippedPackets > 1_000_000 { break } // safety
                }
                // Fall through to normal playback if we never found target.
            }

            await beginPlayback()

        } catch {
            let msg = (error as? CustomStringConvertible)?.description ?? error.localizedDescription
            log.error("Playback failed: \(msg)")
            await MainActor.run {
                self.playerError = msg
                self.playerState = .failed(message: msg)
                self.isPlaying = false
            }
        }
    }

    private nonisolated func beginPlayback() async {
        audioOutput.start()
        await MainActor.run {
            self.isPlaying = true
            self.playerState = .playing
        }
        log.info("beginPlayback: entered, state=.playing")

        var videoFramesDecoded = 0
        var audioBuffersScheduled = 0
        var iterations = 0

        while !Task.isCancelled {
            iterations += 1
            // Pause support: spin lightly while paused.
            if await MainActor.run(body: { !self.isPlaying }) {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                continue
            }

            guard let packet = demuxer.readPacket() else {
                // EOF or error
                let err = await MainActor.run { self.playerError }
                log.info("beginPlayback: readPacket=nil after \(iterations) iters (video=\(videoFramesDecoded) audio=\(audioBuffersScheduled)) err=\(err ?? "nil")")
                if let err {
                    await MainActor.run {
                        self.playerState = .failed(message: err)
                        self.isPlaying = false
                    }
                } else {
                    await MainActor.run {
                        self.playerState = .finished
                        self.isPlaying = false
                    }
                }
                return
            }

            switch packet {
            case .video(let sampleBuffer):
                let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
                let safePTS = pts.isFinite ? pts : 0
                await startClockIfNeeded(atMediaTime: safePTS)
                decoder.decode(
                    sampleBuffer: sampleBuffer,
                    decodeFlags: [],
                    decodeInfoFlags: [],
                    ptsSeconds: safePTS
                )
                videoFramesDecoded += 1

                // Frame-rate pacing: the decode loop would otherwise submit every
                // frame as fast as the hardware decoder can chew them (the whole
                // 417s clip in a few seconds), which leaves
                // AVSampleBufferDisplayLayer unable to present them in time → black
                // screen. Sleep so this frame lines up with the master clock's
                // current media position before the next iteration.
                let mediaNow = await MainActor.run { self.clock.currentMediaTime }
                let ahead = safePTS - mediaNow
                if ahead > 0.010 {  // only pace when meaningfully ahead of playback
                    let sleepNS = UInt64(min(ahead, 0.1) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: sleepNS)
                }

                if videoFramesDecoded == 1 || videoFramesDecoded % 60 == 0 {
                    log.info("beginPlayback: decoded video frame #\(videoFramesDecoded) pts=\(safePTS, format: .fixed(precision: 3)) mediaNow=\(mediaNow, format: .fixed(precision: 3))")
                }

            case .audio(let pcm, let pts):
                let safePTS = pts.isFinite ? pts : 0
                await startClockIfNeeded(atMediaTime: safePTS)
                audioOutput.schedulePCM(pcm)
                audioBuffersScheduled += 1

            case .endOfFile:
                log.info("beginPlayback: EOF after video=\(videoFramesDecoded) audio=\(audioBuffersScheduled)")
                await MainActor.run {
                    self.playerState = .finished
                    self.isPlaying = false
                }
                return
            }
        }
        log.info("beginPlayback: loop cancelled")
    }

    @MainActor
    private func startClockIfNeeded(atMediaTime mediaTime: Double) {
        guard !clock.isRunning else { return }
        clock.start(atMediaTime: mediaTime)
        currentTime = mediaTime
    }

    private nonisolated func scheduleVideoFrame(
        pixelBuffer: CVPixelBuffer,
        ptsSeconds: TimeInterval,
        generation: Int
    ) {
        nonisolated(unsafe) let pb = pixelBuffer
        Task { @MainActor [weak self] in
            guard let self, self.playbackGeneration == generation else { return }

            let safePTS = ptsSeconds.isFinite ? ptsSeconds : 0
            let delay = safePTS - self.clock.currentMediaTime
            if delay > 0.005 {
                let sleepNS = UInt64(min(delay, 0.25) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: sleepNS)
            }

            guard self.playbackGeneration == generation, self.isPlaying else { return }
            let lateness = self.clock.currentMediaTime - safePTS
            let frameInterval = self.nominalFrameRate > 0 ? 1 / Double(self.nominalFrameRate) : 1 / 25
            let maxLateness = max(0.120, frameInterval * 3)
            if lateness > maxLateness {
                self.lateVideoFrameDropCount += 1
                let n = self.lateVideoFrameDropCount
                if n <= 3 || n % 30 == 0 {
                    self.log.info("dropping late video frame #\(n) pts=\(safePTS, format: .fixed(precision: 3)) lateness=\(lateness, format: .fixed(precision: 3))")
                }
                return
            }

            self.currentTime = safePTS
            let cmPTS = CMTime(seconds: safePTS, preferredTimescale: 600)
            self.onVideoFrame?(pb, cmPTS)
        }
    }
}

public enum IOSHEVCPlayerError: Error, CustomStringConvertible {
    case noVideoFormat
    case vtDecoderUnavailable

    public var description: String {
        switch self {
        case .noVideoFormat: return "Video track has no CMVideoFormatDescription"
        case .vtDecoderUnavailable: return "VideoToolbox could not create a decompression session (hardware+software+HEV1-rebuild all failed)"
        }
    }
}
#endif

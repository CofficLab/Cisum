#if os(iOS)
import Foundation
import AVFoundation
import os

/// AVAudioEngine-based audio output for HEVC player.
///
/// Receives AVAudioPCMBuffer instances (decoded by `AVAssetReader` from the source
/// MP4's AAC track) and schedules them on the engine's main mixer for playback.
public final class AVAudioEngineHEVCOutput: @unchecked Sendable {

    private let log = Logger(subsystem: "com.coffic.cisum", category: "audio.engine")
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isStarted = false

    public init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
    }

    deinit {
        engine.stop()
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true

        // On iOS the AVAudioSession must be active before AVAudioEngine can
        // start. The app's bootstrap configures it, but we re-assert here so
        // a reordered or re-created output still works.
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(true, options: [])
        } catch {
            log.error("AVAudioSession setActive failed: \(error.localizedDescription)")
        }
        #endif

        do {
            try engine.start()
            try player.play()
            let outputFormat = engine.outputNode.inputFormat(forBus: 0)
            log.info("AVAudioEngine started: \(outputFormat.sampleRate)Hz \(outputFormat.channelCount)ch")
        } catch {
            log.error("Failed to start AVAudioEngine: \(error.localizedDescription)")
        }
    }

    public func stop() {
        guard isStarted else { return }
        player.stop()
        engine.stop()
        isStarted = false
    }

    public func pause() {
        player.pause()
    }

    public func resume() {
        if !engine.isRunning { try? engine.start() }
        if !player.isPlaying { try? player.play() }
    }

    /// Schedule a PCM buffer for playback.
    public func schedulePCM(_ pcm: AVAudioPCMBuffer) {
        guard isStarted else { return }
        do {
            try player.scheduleBuffer(pcm, at: nil, options: [], completionHandler: nil)
            if scheduleCallCount == 0 {
                log.info("schedulePCM: first buffer \(pcm.frameLength) frames @ \(pcm.format.sampleRate)Hz")
            }
            scheduleCallCount += 1
        } catch {
            log.error("Failed to schedule PCM buffer: \(error.localizedDescription)")
        }
    }
    private var scheduleCallCount = 0
}
#endif

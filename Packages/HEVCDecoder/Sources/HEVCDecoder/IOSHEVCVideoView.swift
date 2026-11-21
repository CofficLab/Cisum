#if os(iOS)
import UIKit
import AVFoundation
import CoreMedia
import CoreVideo
import os

/// iOS UIView whose backing layer is an `AVSampleBufferDisplayLayer`.
///
/// `AVSampleBufferDisplayLayer` is the canonical way to display decoded video
/// frames on iOS without going through `AVPlayer` / `VideoPlayer`. It handles
/// vsync, color management (including HDR/P3 → SDR tonemapping), rotation, and
/// aspect-fit/gravity internally — we just feed it `CMSampleBuffer`s.
///
/// Use the companion `IOSHEVCVideoLayerView` SwiftUI wrapper when embedding
/// inside a SwiftUI hierarchy.
public final class IOSHEVCVideoView: UIView {

    /// The backing display layer. Exposed for advanced consumers (e.g. setting
    /// `controlTimebase` for external clock sync).
    public var displayLayer: AVSampleBufferDisplayLayer {
        // Force-unwrap is safe: we override `layerClass` to this type below.
        return layer as! AVSampleBufferDisplayLayer
    }

    /// Pixel format that the display layer expects (NV12 bi-planar YUV).
    /// Matches the output of `VideoToolboxHEVCDecoder`.
    private static let preferredPixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange

    private let log = Logger(subsystem: "com.coffic.cisum", category: "ios.hevc.view")
    private var formatDescription: CMVideoFormatDescription?
    private var enqueuedFrameCount = 0
    private var droppedFrameCount = 0

    /// Control timebase for the display layer. Without it, the layer uses an
    /// implicit time base and treats sample PTS values as "future" frames,
    /// holding them indefinitely → black screen. We create a CMTimebase, align
    /// its time to the first frame's PTS, set rate 1.0, and assign it before
    /// the first enqueue so frames become "due" and actually display.
    private var controlTimebase: CMTimebase?
    private var timebaseInitialized = false

    // MARK: - Init

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonInit() {
        backgroundColor = .black
        isOpaque = true
        clipsToBounds = true
        displayLayer.videoGravity = .resizeAspect
    }

    // Use AVSampleBufferDisplayLayer as the CoreAnimation backing layer.
    public override class var layerClass: AnyClass {
        return AVSampleBufferDisplayLayer.self
    }

    // MARK: - Format

    /// Set the format description before enqueuing frames. Must be called
    /// once per stream — typically from `IOSHEVCPlayer.onSessionReady`.
    public func setFormatDescription(_ formatDescription: CMVideoFormatDescription) {
        self.formatDescription = formatDescription
        // A new stream starts: reset the timebase so it gets re-anchored to the
        // new first frame's PTS on the next enqueue.
        timebaseInitialized = false
        controlTimebase = nil
        displayLayer.controlTimebase = nil
        let dims = CMVideoFormatDescriptionGetDimensions(formatDescription)
        log.info("setFormatDescription: \(Int(dims.width))x\(Int(dims.height))")
    }

    // MARK: - Enqueue

    /// Submit a decoded frame for display at the given presentation time.
    /// Safe to call from any thread; the display layer synchronizes internally.
    public func enqueue(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        // First-frame diagnostics: verify the pixel buffer is valid and non-empty
        // so we can tell a content problem (empty/recycled buffer) from a layer
        // problem (failed/zero-size).
        if enqueuedFrameCount == 0 {
            let w = CVPixelBufferGetWidth(pixelBuffer)
            let h = CVPixelBufferGetHeight(pixelBuffer)
            let fmt = CVPixelBufferGetPixelFormatType(pixelBuffer)
            let fmtStr = String(format: "%c%c%c%c",
                                (fmt >> 24) & 0xFF, (fmt >> 16) & 0xFF,
                                (fmt >> 8) & 0xFF, fmt & 0xFF)
            let isPlanar = CVPixelBufferIsPlanar(pixelBuffer)
            let planeCount = CVPixelBufferGetPlaneCount(pixelBuffer)
            log.info("pixelBuffer: \(w)x\(h) fmt=\(fmtStr) planar=\(isPlanar) planes=\(planeCount)")
        }
        // Build the sample buffer from the pixel buffer's own (uncompressed)
        // format description — see makeSampleBuffer for why the stored HEVC
        // compressed formatDescription cannot be used directly.
        guard let sampleBuffer = makeSampleBuffer(
            pixelBuffer: pixelBuffer,
            formatDescription: formatDescription,
            presentationTime: presentationTime
        ) else {
            log.error("Failed to wrap pixel buffer into CMSampleBuffer")
            return
        }

        if displayLayer.isReadyForMoreMediaData {
            // Set up the control timebase on (or just before) the first frame.
            // Without it the layer treats PTS as future frames and never
            // displays them (black screen). We align the timebase to the first
            // sample's PTS and start it at rate 1.0.
            if !timebaseInitialized {
                initializeTimebase(forFirstSamplePTS: presentationTime)
            }
            displayLayer.enqueue(sampleBuffer)
            enqueuedFrameCount += 1
            if enqueuedFrameCount == 1 {
                let statusRaw = displayLayer.status.rawValue
                let f = displayLayer.frame
                let b = displayLayer.bounds
                let inWin = self.window != nil ? "yes" : "no"
                let hasSuper = self.superview != nil ? "yes" : "no"
                log.info("first frame enqueued at pts=\(presentationTime.seconds) (layer status=\(statusRaw)) frame=\(Int(f.width))x\(Int(f.height)) bounds=\(Int(b.width))x\(Int(b.height)) inWindow=\(inWin) hasSuper=\(hasSuper) gravity=\(self.displayLayer.videoGravity.rawValue)")
            } else if enqueuedFrameCount % 60 == 0 {
                let n = enqueuedFrameCount
                let statusRaw = displayLayer.status.rawValue
                let b = displayLayer.bounds
                let err = displayLayer.error?.localizedDescription ?? "nil"
                log.info("enqueue #\(n) status=\(statusRaw) bounds=\(Int(b.width))x\(Int(b.height)) err=\(err)")
            }
        } else {
            droppedFrameCount += 1
            let n = droppedFrameCount
            let statusRaw = displayLayer.status.rawValue
            let errMsg = displayLayer.error?.localizedDescription ?? "nil"
            if n <= 3 || n % 30 == 0 {
                log.info("display layer not ready — dropping frame #\(n) (status=\(statusRaw) err=\(errMsg))")
            }
        }
    }

    /// Discard any frames still queued for display. Call this after a seek so
    /// stale frames from the previous playback position don't pop in.
    public func flush() {
        displayLayer.flushAndRemoveImage()
        log.info("display layer flushed")
    }

    /// Create and assign the display layer's control timebase, anchored so the
    /// first sample's PTS lines up with "now". The display layer needs a running
    /// timebase (rate 1.0) to decide when each enqueued frame is "due"; without
    /// one it holds frames with future PTS indefinitely → black screen.
    private func initializeTimebase(forFirstSamplePTS pts: CMTime) {
        timebaseInitialized = true
        // CMClockGetHostTimeClock() is the same clock CACurrentMediaTime() uses.
        let clock = CMClockGetHostTimeClock()
        var timebase: CMTimebase?
        let createStatus = CMTimebaseCreateWithSourceClock(
            allocator: kCFAllocatorDefault,
            sourceClock: clock,
            timebaseOut: &timebase
        )
        guard createStatus == noErr, let tb = timebase else {
            log.error("initializeTimebase: CMTimebaseCreate failed \(createStatus)")
            return
        }
        // Align the timebase's current time to the first sample's PTS and start
        // it at rate 1.0 so subsequent PTS values become "due" at the right pace.
        CMTimebaseSetTime(tb, time: pts)
        CMTimebaseSetRate(tb, rate: 1.0)
        displayLayer.controlTimebase = tb
        controlTimebase = tb
        log.info("initializeTimebase: set to pts=\(pts.seconds) rate=1.0")
    }

    // MARK: - Helpers

    private func makeSampleBuffer(
        pixelBuffer: CVPixelBuffer,
        formatDescription: CMVideoFormatDescription?,
        presentationTime: CMTime
    ) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )
        // The formatDescription stored on this view is the HEVC *compressed*
        // description (subtype hev1/hvc1), but CMSampleBufferCreateForImageBuffer
        // requires a description of the UNCOMPRESSED pixel buffer (subtype like
        // '420v'). Passing the HEVC desc yields -12743
        // (kCMSampleBufferError_RequiredParameterMissingErr). Derive the correct
        // uncompressed format description from the pixel buffer itself.
        var imageFormatDesc: CMVideoFormatDescription?
        let fdStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &imageFormatDesc
        )
        guard fdStatus == noErr, let desc = imageFormatDesc else {
            log.error("CMVideoFormatDescriptionCreateForImageBuffer failed: \(fdStatus)")
            return nil
        }
        let status = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: desc,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        if status != noErr {
            log.error("CMSampleBufferCreateForImageBuffer failed: \(status)")
            return nil
        }
        return sampleBuffer
    }
}

import SwiftUI

/// SwiftUI wrapper for `IOSHEVCVideoView`.
///
/// Forwards `IOSHEVCPlayer.onVideoFrame` to the underlying view's
/// `enqueue(pixelBuffer:presentationTime:)` and forwards
/// `IOSHEVCPlayer.onSessionReady` to `setFormatDescription`.
public struct IOSHEVCVideoLayerView: UIViewRepresentable {

    @ObservedObject public var player: IOSHEVCPlayer

    public init(player: IOSHEVCPlayer) {
        self.player = player
    }

    public func makeUIView(context: Context) -> IOSHEVCVideoView {
        let view = IOSHEVCVideoView()
        context.coordinator.attach(player: player, to: view)
        return view
    }

    public func updateUIView(_ uiView: IOSHEVCVideoView, context: Context) {
        // Re-attach on player swap (SwiftUI may reuse the view).
        context.coordinator.attach(player: player, to: uiView)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    public final class Coordinator {
        private var frameObserver: ((CVPixelBuffer, CMTime) -> Void)?
        private var sessionObserver: ((CMVideoFormatDescription) -> Void)?
        private weak var attachedPlayer: IOSHEVCPlayer?
        private weak var attachedView: IOSHEVCVideoView?

        func attach(player: IOSHEVCPlayer, to view: IOSHEVCVideoView) {
            // De-dup: only re-wire when something actually changed.
            if attachedPlayer === player, attachedView === view { return }

            // Detach previous wiring.
            if let prev = attachedPlayer {
                prev.onVideoFrame = nil
                prev.onSessionReady = nil
            }

            attachedPlayer = player
            attachedView = view

            // Wire the new player. Both callbacks run on the main actor because
            // `IOSHEVCPlayer` is @MainActor-isolated.
            player.onSessionReady = { [weak view] formatDesc in
                view?.setFormatDescription(formatDesc)
            }
            player.onVideoFrame = { [weak view] pixelBuffer, pts in
                view?.enqueue(pixelBuffer: pixelBuffer, presentationTime: pts)
            }
        }
    }
}
#endif

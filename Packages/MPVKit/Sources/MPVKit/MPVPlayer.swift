import Foundation
import MPVC
import Combine
import os
import MagicKit
import CoreVideo

#if os(macOS)
import AppKit
import OpenGL.GL
import OpenGL.GL3

/// Swift wrapper around libmpv's C API.
///
/// Owns the mpv handle, the OpenGL context, and the mpv render context.
/// The render context is created during initialization (before any file is
/// loaded) to avoid the race condition where `loadfile` is sent before the
/// render context exists — which causes mpv to fall back to idle state and
/// never produce video frames.
public final class MPVPlayer: ObservableObject, SuperLog {
    nonisolated public static let emoji = "🎬"
    nonisolated public static let author = "MPVPlayer"
    nonisolated public static let verbose = false
    nonisolated public static let logger = Logger(subsystem: "com.coffic.cisum", category: "mpv.player")

    // MARK: - Published State

    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTime: Double = 0
    @Published public private(set) var duration: Double = 0
    @Published public private(set) var playerState: MPVPlayerState = .idle
    @Published public private(set) var playerError: String?
    @Published public private(set) var videoSize: CGSize = .zero

    public var playbackRate: Double = 1.0 {
        didSet {
            if mpv != nil {
                setProperty("speed", playbackRate)
            }
        }
    }

    // MARK: - Internal

    var mpv: OpaquePointer?

    /// The mpv render context, created during `setupMPV()` so that it is
    /// available before any `loadfile` command is sent.
    var mpvRenderContext: OpaquePointer?

    /// The CGL OpenGL context used for rendering. Created in `setupMPV()` and
    /// shared with `MPVOpenGLLayer` via `copyCGLContext`.
    var cglContext: CGLContextObj?

    /// The CGL pixel format used for rendering.
    var cglPixelFormat: CGLPixelFormatObj?

    /// Callback invoked by mpv when a new frame is ready. The layer sets this
    /// to trigger a redisplay on the main thread.
    var renderUpdateCallback: (() -> Void)?

    private let log = Logger(subsystem: "com.coffic.cisum", category: "mpv.player")
    private var eventThread: Thread?

    /// URL currently being held under a security-scoped resource access.
    /// Released when the file is loaded or playback ends.
    private var heldSecurityURL: URL?

    public init() {
        setupMPV()
    }

    deinit {
        stopEventThread()
        releaseSecurityScope()
        if let ctx = mpvRenderContext {
            mpv_render_context_set_update_callback(ctx, nil, nil)
            mpv_render_context_free(ctx)
        }
        if let mpv = mpv {
            mpv_terminate_destroy(mpv)
        }
        if let pf = cglPixelFormat {
            CGLDestroyPixelFormat(pf)
        }
        if let ctx = cglContext {
            CGLClearDrawable(ctx)
            CGLDestroyContext(ctx)
        }
    }

    // MARK: - Setup

    private func setupMPV() {
        mpv = mpv_create()
        guard let mpv else {
            playerState = .failed(message: "Failed to create mpv instance")
            return
        }

        // Configure mpv
        setOptionString("vo", "libmpv")
        setOptionString("hwdec", "videotoolbox")
        setOptionString("ao", "coreaudio")
        setOptionFlag("idle", true)

        // Initialize
        let err = mpv_initialize(mpv)
        guard err >= 0 else {
            playerState = .failed(message: "mpv_initialize failed")
            return
        }

        // Create the OpenGL context and mpv render context BEFORE any
        // loadfile command. This avoids the race where mpv receives
        // loadfile but has no render context, causing it to stay idle.
        setupOpenGLContext()
        setupMPVRenderContext()

        // `force-window=immediate` tells mpv to create the VO immediately.
        // Must be set AFTER the render context exists to avoid racing the
        // VO thread against render context setup (per IINA PlayerCore.initVideo).
        setPropertyString("force-window", "immediate")

        // Observe properties (double-valued, queried via event loop)
        observeProperty("time-pos")
        observeProperty("duration")

        // Start event thread
        startEventThread()

        playerState = .idle
        if Self.verbose {
            Self.logger.info("\(Self.t)mpv initialized with render context")
        }
    }

    // MARK: - OpenGL / Render Context Setup

    private func setupOpenGLContext() {
        // Create pixel format
        var pix: CGLPixelFormatObj?
        var npix: GLint = 0

        let attributes: [CGLPixelFormatAttribute] = [
            kCGLPFAOpenGLProfile,
            CGLPixelFormatAttribute(kCGLOGLPVersion_3_2_Core.rawValue),
            kCGLPFAAccelerated,
            kCGLPFADoubleBuffer,
            kCGLPFAColorSize,
            CGLPixelFormatAttribute(24),
            kCGLPFAAlphaSize,
            CGLPixelFormatAttribute(8),
            kCGLPFASupportsAutomaticGraphicsSwitching,
            CGLPixelFormatAttribute(0)
        ]

        let err = CGLChoosePixelFormat(attributes, &pix, &npix)
        guard err == kCGLNoError, let pixelFormat = pix else {
            log.error("Failed to create pixel format: \(err.rawValue)")
            return
        }
        cglPixelFormat = pixelFormat

        // Create context
        var ctx: CGLContextObj?
        let ctxErr = CGLCreateContext(pixelFormat, nil, &ctx)
        guard ctxErr == kCGLNoError, let context = ctx else {
            log.error("Failed to create OpenGL context: \(ctxErr.rawValue)")
            return
        }
        cglContext = context

        // Enable vertical sync
        var swapInterval: GLint = 1
        CGLSetParameter(context, kCGLCPSwapInterval, &swapInterval)

        // Enable multi-threaded GL engine (per IINA ViewLayer.createContext)
        CGLEnable(context, kCGLCEMPEngine)

        CGLSetCurrentContext(context)
    }

    private func setupMPVRenderContext() {
        guard let mpv = mpv, let cglCtx = cglContext else {
            log.error("Cannot create render context: mpv or cglContext is nil")
            return
        }

        CGLSetCurrentContext(cglCtx)

        var glInitParams = mpv_opengl_init_params(
            get_proc_address: { ctx, name in
                guard let name = name else { return nil }
                let symbolName = String(cString: name)
                let symbol = CFBundleGetFunctionPointerForName(
                    CFBundleGetBundleWithIdentifier("com.apple.opengl" as CFString),
                    symbolName as CFString
                )
                return symbol
            },
            get_proc_address_ctx: nil
        )

        let apiType = UnsafeMutableRawPointer(mutating: (MPV_RENDER_API_TYPE_OPENGL as NSString).utf8String)

        withUnsafeMutablePointer(to: &glInitParams) { glInitParams in
            var advanced: CInt = 1
            withUnsafeMutablePointer(to: &advanced) { advanced in
                var params: [mpv_render_param] = [
                    mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE, data: apiType),
                    mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, data: UnsafeMutableRawPointer(glInitParams)),
                    mpv_render_param(type: MPV_RENDER_PARAM_ADVANCED_CONTROL, data: UnsafeMutableRawPointer(advanced)),
                    mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil)
                ]

                var ctx: OpaquePointer?
                let err = mpv_render_context_create(&ctx, mpv, &params)
                guard err >= 0, let renderCtx = ctx else {
                    log.error("Failed to create mpv render context: \(err)")
                    return
                }
                mpvRenderContext = renderCtx
            }
        }

        // Set the render update callback. mpv calls this when a new frame is
        // available. We forward to the layer via the closure.
        if let renderCtx = mpvRenderContext {
            mpv_render_context_set_update_callback(renderCtx, { ctx in
                guard let ctx else { return }
                let player = Unmanaged<MPVPlayer>.fromOpaque(ctx).takeUnretainedValue()
                DispatchQueue.main.async {
                    player.renderUpdateCallback?()
                }
            }, Unmanaged.passUnretained(self).toOpaque())
        }
    }

    /// Called by the layer's `canDraw` to check if mpv has a new frame.
    /// Mirrors IINA's `shouldRenderUpdateFrame()`.
    func shouldRenderUpdateFrame() -> Bool {
        guard let renderCtx = mpvRenderContext else { return false }
        let flags: UInt64 = mpv_render_context_update(renderCtx)
        return flags & UInt64(MPV_RENDER_UPDATE_FRAME.rawValue) > 0
    }

    // MARK: - Controls

    public func play(url: URL) {
        guard let mpv else { return }

        // Release any previously held security-scoped URL.
        releaseSecurityScope()

        // Start security-scoped access and hold it until the file is loaded
        // or playback ends. mpv_command(loadfile) is asynchronous — mpv opens
        // the file on its internal thread, so we must keep the scope alive.
        let needsScoped = url.startAccessingSecurityScopedResource()
        if needsScoped {
            heldSecurityURL = url
        }

        // Load file
        "loadfile".withCString { cmdPtr in
            url.path.withCString { pathPtr in
                "replace".withCString { modePtr in
                    var args: [UnsafePointer<CChar>?] = [cmdPtr, pathPtr, modePtr, nil]
                    let err = mpv_command(mpv, &args)

                    if err < 0 {
                        DispatchQueue.main.async {
                            self.releaseSecurityScope()
                            self.playerState = .failed(message: "loadfile failed")
                            self.playerError = String(cString: mpv_error_string(err))
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.playerState = .loading
                            if Self.verbose {
                                Self.logger.info("\(Self.t)loadfile: \(url.lastPathComponent)")
                            }
                        }
                    }
                }
            }
        }
    }

    /// Release the security-scoped resource access for the held URL.
    private func releaseSecurityScope() {
        if let url = heldSecurityURL {
            url.stopAccessingSecurityScopedResource()
            heldSecurityURL = nil
        }
    }

    public func pause() {
        setProperty("pause", true)
        isPlaying = false
    }

    public func resume() {
        setProperty("pause", false)
        isPlaying = true
    }

    public func stop() {
        guard let mpv else { return }
        "stop".withCString { cmdPtr in
            var args: [UnsafePointer<CChar>?] = [cmdPtr, nil]
            mpv_command(mpv, &args)
        }
        DispatchQueue.main.async {
            self.isPlaying = false
            self.playerState = .idle
        }
    }

    public func seek(to seconds: Double) {
        guard let mpv else { return }
        "seek".withCString { cmdPtr in
            "\(seconds)".withCString { timePtr in
                "absolute".withCString { modePtr in
                    var args: [UnsafePointer<CChar>?] = [cmdPtr, timePtr, modePtr, nil]
                    mpv_command(mpv, &args)
                }
            }
        }
    }

    // MARK: - Event Loop

    private func startEventThread() {
        eventThread = Thread {
            while !Thread.current.isCancelled {
                self.readEvents()
            }
        }
        eventThread?.start()
    }

    private func stopEventThread() {
        eventThread?.cancel()
    }

    private func readEvents() {
        guard let mpv else { return }
        let event = mpv_wait_event(mpv, 0.1)
        guard let event = event?.pointee else { return }

        if event.event_id == MPV_EVENT_PROPERTY_CHANGE {
            handlePropertyChange(event)
        } else if event.event_id == MPV_EVENT_FILE_LOADED {
            DispatchQueue.main.async {
                self.playerState = .playing
                self.isPlaying = true
            }
        } else if event.event_id == MPV_EVENT_END_FILE {
            DispatchQueue.main.async {
                // Release security-scoped access when playback ends.
                self.releaseSecurityScope()
                self.playerState = .finished
                self.isPlaying = false
            }
        }
    }

    private func handlePropertyChange(_ event: mpv_event) {
        guard let data = event.data else { return }
        let prop = data.load(as: mpv_event_property.self)
        let name = String(cString: prop.name)

        if name == "time-pos", let ptr = prop.data {
            let time = ptr.load(as: Double.self)
            DispatchQueue.main.async {
                self.currentTime = time
            }
        } else if name == "duration", let ptr = prop.data {
            let dur = ptr.load(as: Double.self)
            DispatchQueue.main.async {
                self.duration = dur
            }
        }
    }

    // MARK: - Helpers

    private func setOptionString(_ name: String, _ value: String) {
        guard let mpv else { return }
        mpv_set_option_string(mpv, name, value)
    }

    private func setOptionFlag(_ name: String, _ value: Bool) {
        guard let mpv else { return }
        var v: Int32 = value ? 1 : 0
        mpv_set_option(mpv, name, MPV_FORMAT_FLAG, &v)
    }

    private func setProperty(_ name: String, _ value: Double) {
        guard let mpv else { return }
        var v = value
        mpv_set_property(mpv, name, MPV_FORMAT_DOUBLE, &v)
    }

    private func setProperty(_ name: String, _ value: Bool) {
        guard let mpv else { return }
        var v: Int32 = value ? 1 : 0
        mpv_set_property(mpv, name, MPV_FORMAT_FLAG, &v)
    }

    private func observeProperty(_ name: String) {
        guard let mpv else { return }
        mpv_observe_property(mpv, 0, name, MPV_FORMAT_DOUBLE)
    }

    // MARK: - Property Helpers (String-based)

    /// Set a string property on the mpv handle (post-initialization).
    private func setPropertyString(_ name: String, _ value: String) {
        guard let mpv else { return }
        mpv_set_property_string(mpv, name, value)
    }

    // MARK: - Diagnostics

    /// 获取 mpv 属性的字符串值
    public func getPropertyString(_ name: String) -> String? {
        guard let mpv else { return nil }
        var value: UnsafeMutablePointer<CChar>?
        let err = mpv_get_property(mpv, name, MPV_FORMAT_STRING, &value)
        guard err >= 0, let ptr = value else { return nil }
        defer { mpv_free(ptr) }
        return String(cString: ptr)
    }

    /// 诊断当前播放状态
    public func diagnosePlayback() -> String {
        var report = "=== MPV Playback Diagnostics ===\n"

        if let path = getPropertyString("path") {
            report += "Current file: \(path)\n"
        } else {
            report += "Current file: (none)\n"
        }

        if let mediaTitle = getPropertyString("media-title") {
            report += "Media title: \(mediaTitle)\n"
        }

        report += "Pause: \(getPropertyString("pause") ?? "unknown")\n"
        report += "Idle: \(getPropertyString("idle") ?? "unknown")\n"
        report += "Playback abort: \(getPropertyString("playback-abort") ?? "unknown")\n"

        if let videoParams = getPropertyString("video-params") {
            report += "Video params: \(videoParams)\n"
        } else {
            report += "Video params: (none)\n"
        }

        if let videoFormat = getPropertyString("video-format") {
            report += "Video format: \(videoFormat)\n"
        }

        if let containerFps = getPropertyString("container-fps") {
            report += "Container FPS: \(containerFps)\n"
        }

        if let estimatedFps = getPropertyString("estimated-frame-count") {
            report += "Estimated frames: \(estimatedFps)\n"
        }

        if let vo = getPropertyString("current-vo") {
            report += "Video output: \(vo)\n"
        }

        if let ao = getPropertyString("current-ao") {
            report += "Audio output: \(ao)\n"
        }

        report += "================================\n"
        return report
    }
}

public enum MPVPlayerState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case finished
    case failed(message: String)
}
#endif

import SwiftUI
import os
import MPVC
import CoreVideo
import MagicKit

#if os(macOS)
import AppKit
import OpenGL.GL
import OpenGL.GL3

/// SwiftUI view that renders mpv video output via the player's render context.
public struct MPVVideoView: View {
    @ObservedObject var player: MPVPlayer

    public init(player: MPVPlayer) {
        self.player = player
    }

    public var body: some View {
        MPVVideoNSView(player: player)
    }
}

/// NSViewRepresentable wrapper for the CAOpenGLLayer-based video view.
struct MPVVideoNSView: NSViewRepresentable {
    @ObservedObject var player: MPVPlayer

    func makeNSView(context: Context) -> MPVVideoViewImpl {
        let view = MPVVideoViewImpl(player: player)
        view.frame = NSRect(x: 0, y: 0, width: 960, height: 540)
        return view
    }

    func updateNSView(_ nsView: MPVVideoViewImpl, context: Context) {
        // No update needed
    }
}

/// NSView that hosts the `MPVOpenGLLayerImpl`. The layer retrieves the render
/// context, CGL context, and pixel format from the `MPVPlayer` (which created
/// them during `setupMPV()`). This avoids the race condition where the render
/// context did not exist when `loadfile` was sent.
class MPVVideoViewImpl: NSView, SuperLog {
    nonisolated static let emoji = "🎥"
    nonisolated static let author = "MPVVideoViewImpl"
    nonisolated static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.cisum", category: "mpv.video")
    weak var player: MPVPlayer?
    private var videoLayer: MPVOpenGLLayerImpl?
    private var diagnosticTimer: Timer?

    init(player: MPVPlayer) {
        self.player = player
        super.init(frame: .zero)

        let layer = MPVOpenGLLayerImpl(player: player)
        self.videoLayer = layer

        self.layer = layer
        self.wantsLayer = true
        self.autoresizingMask = [.width, .height]

        // Register the layer's setNeedsDisplay as the render update callback
        // so mpv can trigger redraws when new frames are available.
        player.renderUpdateCallback = { [weak layer] in
            layer?.setNeedsDisplay()
        }

        if Self.verbose { Self.logger.info("\(Self.t)[MPVVideoView] View initialized with player") }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startDiagnosticTimer()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        diagnosticTimer?.invalidate()
    }

    private func startDiagnosticTimer() {
        diagnosticTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.printDiagnostics()
        }
    }

    private func printDiagnostics() {
        guard let player = player else { return }
        if Self.verbose { Self.logger.info("\(Self.t)\(player.diagnosePlayback())") }
    }

    override func layout() {
        super.layout()
        videoLayer?.updateViewSize(bounds)
        if Self.verbose { Self.logger.info("\(Self.t)[MPVVideoView] Layout: \(String(describing: self.bounds))") }
    }
}

/// OpenGL layer that renders mpv video frames. Uses the render context,
/// CGL context, and pixel format owned by `MPVPlayer`.
class MPVOpenGLLayerImpl: CAOpenGLLayer, SuperLog {
    nonisolated static let emoji = "🖥️"
    nonisolated static let author = "MPVOpenGLLayerImpl"
    nonisolated static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.cisum", category: "mpv.opengl")
    private weak var player: MPVPlayer?
    private var viewSize: CGSize = CGSize(width: 960, height: 540)

    init(player: MPVPlayer) {
        self.player = player
        super.init()

        if Self.verbose { Self.logger.info("\(Self.t)[MPVOpenGLLayer] Initializing with player render context...") }

        self.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        self.backgroundColor = NSColor.black.cgColor
        self.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        self.contentsGravity = .resizeAspectFill
        self.isAsynchronous = false

        if Self.verbose { Self.logger.info("\(Self.t)[MPVOpenGLLayer] Initialized, render context: \(player.mpvRenderContext != nil)") }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateViewSize(_ size: CGRect) {
        viewSize = size.size
        setNeedsDisplay()
    }

    // MARK: - CGL overrides (use player's context & pixel format)

    override func copyCGLPixelFormat(forDisplayMask mask: UInt32) -> CGLPixelFormatObj {
        return player?.cglPixelFormat ?? super.copyCGLPixelFormat(forDisplayMask: mask)
    }

    override func copyCGLContext(forPixelFormat pf: CGLPixelFormatObj) -> CGLContextObj {
        return player?.cglContext ?? super.copyCGLContext(forPixelFormat: pf)
    }

    // MARK: - Drawing

    override func canDraw(inCGLContext ctx: CGLContextObj, pixelFormat pf: CGLPixelFormatObj,
                          forLayerTime t: CFTimeInterval, displayTime ts: UnsafePointer<CVTimeStamp>?) -> Bool {
        return player?.shouldRenderUpdateFrame() ?? false
    }

    override func draw(inCGLContext ctx: CGLContextObj, pixelFormat pf: CGLPixelFormatObj,
                       forLayerTime t: CFTimeInterval, displayTime ts: UnsafePointer<CVTimeStamp>?) {
        guard let renderCtx = player?.mpvRenderContext else {
            if Self.verbose { Self.logger.info("\(Self.t)[MPVOpenGLLayer] draw: render context is nil") }
            return
        }

        CGLSetCurrentContext(ctx)
        CGLLockContext(ctx)
        defer { CGLUnlockContext(ctx) }

        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        var fbo: GLint = 0
        glGetIntegerv(GLenum(GL_DRAW_FRAMEBUFFER_BINDING), &fbo)

        var dims: [GLint] = [0, 0, 0, 0]
        glGetIntegerv(GLenum(GL_VIEWPORT), &dims)

        let width = Int32(dims[2])
        let height = Int32(dims[3])

        var flipY: CInt = 1

        withUnsafeMutablePointer(to: &flipY) { flipYPtr in
            var fboParams = mpv_opengl_fbo(fbo: fbo, w: width, h: height, internal_format: 0)
            withUnsafeMutablePointer(to: &fboParams) { fboParamsPtr in
                var params: [mpv_render_param] = [
                    mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_FBO, data: UnsafeMutableRawPointer(fboParamsPtr)),
                    mpv_render_param(type: MPV_RENDER_PARAM_FLIP_Y, data: UnsafeMutableRawPointer(flipYPtr)),
                    mpv_render_param()
                ]

                let err = mpv_render_context_render(renderCtx, &params)
                if err < 0 {
                    if Self.verbose { Self.logger.info("\(Self.t)[MPVOpenGLLayer] mpv render failed: \(err)") }
                }
            }
        }

        mpv_render_context_report_swap(renderCtx)
        glFlush()
    }

    override func display() {
        if Thread.isMainThread {
            super.display()
        } else {
            CATransaction.begin()
            super.display()
            CATransaction.commit()
        }
        CATransaction.flush()
    }
}
#endif

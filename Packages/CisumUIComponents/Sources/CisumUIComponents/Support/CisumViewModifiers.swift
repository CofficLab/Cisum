import SwiftUI
import LumiUI

public extension View {
    func cisumInfinite() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func cisumInfiniteHeight(alignment: Alignment = .center) -> some View {
        frame(maxHeight: .infinity, alignment: alignment)
    }

    @ViewBuilder
    func cisumIf(_ condition: Bool) -> some View {
        if condition {
            self
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    func cisumIf<Else: View>(_ condition: Bool, otherwise: () -> Else) -> some View {
        if condition {
            self
        } else {
            otherwise()
        }
    }

    @ViewBuilder
    func cisumIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    @ViewBuilder
    func cisumIf<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        if trueTransform: (Self) -> TrueContent,
        otherwise falseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            trueTransform(self)
        } else {
            falseTransform(self)
        }
    }

    func cisumButtonNoAction() -> some View {
        Button(action: {}) {
            self
        }
        .buttonStyle(.plain)
    }

    func cisumButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            self
        }
        .buttonStyle(.plain)
    }

    /// 播放控制栏按钮：macOS 悬停放大，全平台按下缩放
    func cisumPlaybackControl(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            self
        }
        .buttonStyle(CisumPlaybackControlButtonStyle())
    }

    func cisumPlaybackControl(accessibilityLabel: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            self.accessibilityHidden(true)
        }
        .buttonStyle(CisumPlaybackControlButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .help(accessibilityLabel)
    }

    func cisumHoverScale(_ scale: CGFloat) -> some View {
        modifier(CisumHoverScaleModifier(scale: scale / 100.0))
    }

    func cisumHoverScale(_ scale: CGFloat, duration: Double) -> some View {
        modifier(CisumHoverScaleModifier(scale: scale / 100.0, duration: duration))
    }

    func cisumShadow(
        color: Color = .black.opacity(0.1),
        radius: CGFloat = 8,
        x: CGFloat = 0,
        y: CGFloat = 2
    ) -> some View {
        shadow(color: color, radius: radius, x: x, y: y)
    }

    func cisumShadowXs() -> some View {
        cisumShadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    func cisumShadowSm() -> some View {
        cisumShadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    func cisumShadowMd() -> some View {
        cisumShadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 1)
    }

    func cisumShadowLg() -> some View {
        cisumShadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)
    }

    func cisumShadowXl() -> some View {
        cisumShadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)
    }

    func cisumShadow2xl() -> some View {
        cisumShadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 12)
    }

    func cisumShadow3xl() -> some View {
        cisumShadow(color: .black.opacity(0.25), radius: 25, x: 0, y: 20)
    }

    func cisumRounded(
        radius: CGFloat = 8,
        style: RoundedCornerStyle = .continuous
    ) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: style))
    }

    func cisumRoundedSmall() -> some View {
        cisumRounded(radius: 4)
    }

    func cisumRoundedMedium() -> some View {
        cisumRounded(radius: 8)
    }

    func cisumRoundedLarge() -> some View {
        cisumRounded(radius: 16)
    }

    func cisumRoundedExtraLarge() -> some View {
        cisumRounded(radius: 24)
    }

    func cisumRoundedFull() -> some View {
        clipShape(Circle())
    }

    func cisumCard(_ material: Material = .regularMaterial) -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.clear.background(material))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    func cisumCard(color: Color) -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    func cisumCentered() -> some View {
        ZStack {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    self
                    Spacer()
                }
                Spacer()
            }
        }
    }

    func cisumVStackCenter(
        spacing: CGFloat? = nil,
        alignment: HorizontalAlignment = .center,
        topSpacer: Bool = true,
        bottomSpacer: Bool = true
    ) -> some View {
        VStack(alignment: alignment, spacing: spacing) {
            if topSpacer {
                Spacer()
            }
            self
            if bottomSpacer {
                Spacer()
            }
        }
    }

    func cisumHStackCenter(
        spacing: CGFloat? = nil,
        alignment: VerticalAlignment = .center,
        leadingSpacer: Bool = true,
        trailingSpacer: Bool = true
    ) -> some View {
        HStack(alignment: alignment, spacing: spacing) {
            if leadingSpacer {
                Spacer()
            }
            self
            if trailingSpacer {
                Spacer()
            }
        }
    }

    func cisumScrollView(
        axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        contentInsets: EdgeInsets? = nil
    ) -> some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            if let contentInsets {
                self.padding(contentInsets)
            } else {
                self
            }
        }
    }

    func cisumDivider(spacing: CGFloat = 0) -> some View {
        VStack(spacing: spacing) {
            self
            Divider()
        }
    }

    func cisumDashedBorder(
        color: Color = .gray,
        lineWidth: CGFloat = 1,
        dash: [CGFloat] = [5, 5]
    ) -> some View {
        overlay(
            Rectangle()
                .strokeBorder(style: StrokeStyle(lineWidth: lineWidth, dash: dash))
                .foregroundColor(color)
        )
    }

    func cisumPt1() -> some View {
        padding(.top, 4)
    }

    func cisumPx2() -> some View {
        padding(.horizontal, 8)
    }

    func cisumPy4() -> some View {
        padding(.vertical, 16)
    }

    func cisumPreviewContainer(
        _ containerSize: CGSize = CGSize(width: 500, height: 750),
        scale: CGFloat = 1.0
    ) -> some View {
        VStack(spacing: 0) {
            self
                .frame(width: containerSize.width, height: containerSize.height)
                .cisumDashedBorder(color: .accentColor)
                .scaleEffect(scale)
                .frame(width: containerSize.width * scale, height: containerSize.height * scale)
        }
        .padding(24)
        .background(.background)
    }

    func inIMacScreen() -> some View {
        CisumIMacScreenFrame {
            self
        }
    }

    func inIPhoneScreen(horizon: Bool = false) -> some View {
        CisumDeviceScreenFrame(
            aspectRatio: horizon ? 19.5 / 9.0 : 9.0 / 19.5,
            cornerRadiusRatio: horizon ? 0.06 : 0.12,
            bezelRatio: 0.055,
            deviceColor: Color(red: 0.07, green: 0.08, blue: 0.09)
        ) {
            self
        }
    }

    func inIPadScreen(horizon: Bool = false) -> some View {
        CisumDeviceScreenFrame(
            aspectRatio: horizon ? 4.0 / 3.0 : 3.0 / 4.0,
            cornerRadiusRatio: 0.055,
            bezelRatio: 0.045,
            deviceColor: Color(red: 0.78, green: 0.77, blue: 0.73)
        ) {
            self
        }
    }

    func inDesktop() -> some View {
        CisumDesktopFrame {
            self
        }
    }
}

public extension CGSize {
    static let cisumIPhone55 = CGSize(width: 1242, height: 2208)
    static let cisumIPhone65 = CGSize(width: 1242, height: 2688)
    static let cisumIPhone69 = CGSize(width: 1290, height: 2796)
    static let cisumMacBook13 = CGSize(width: 2560, height: 1600)
    static let cisumIMac27 = CGSize(width: 5120, height: 2880)
}

private struct CisumPlaybackControlButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        CisumPlaybackControlLabel(configuration: configuration, reduceMotion: reduceMotion)
    }
}

private struct CisumIMacScreenFrame<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            let bezel = max(geo.size.width * 0.035, 8)
            let radius = max(geo.size.width * 0.025, 8)

            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color(red: 0.10, green: 0.11, blue: 0.12))

                    content
                        .clipShape(RoundedRectangle(cornerRadius: radius * 0.55, style: .continuous))
                        .padding(bezel)
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 8)

                RoundedRectangle(cornerRadius: max(radius * 0.2, 2), style: .continuous)
                    .fill(Color(red: 0.68, green: 0.69, blue: 0.70))
                    .frame(width: geo.size.width * 0.16, height: max(geo.size.height * 0.08, 18))

                RoundedRectangle(cornerRadius: max(radius * 0.18, 2), style: .continuous)
                    .fill(Color(red: 0.58, green: 0.59, blue: 0.60))
                    .frame(width: geo.size.width * 0.38, height: max(geo.size.height * 0.035, 10))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

private struct CisumDeviceScreenFrame<Content: View>: View {
    let aspectRatio: CGFloat
    let cornerRadiusRatio: CGFloat
    let bezelRatio: CGFloat
    let deviceColor: Color
    let content: Content

    init(
        aspectRatio: CGFloat,
        cornerRadiusRatio: CGFloat,
        bezelRatio: CGFloat,
        deviceColor: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.aspectRatio = aspectRatio
        self.cornerRadiusRatio = cornerRadiusRatio
        self.bezelRatio = bezelRatio
        self.deviceColor = deviceColor
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            let shortSide = min(geo.size.width, geo.size.height)
            let radius = max(shortSide * cornerRadiusRatio, 12)
            let bezel = max(shortSide * bezelRatio, 8)

            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(deviceColor)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 6)

                content
                    .clipShape(RoundedRectangle(cornerRadius: radius * 0.65, style: .continuous))
                    .padding(bezel)
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

private struct CisumDesktopFrame<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.16, blue: 0.14),
                    Color(red: 0.10, green: 0.34, blue: 0.30),
                    Color(red: 0.34, green: 0.46, blue: 0.42),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            content
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "apple.logo")
                    Text("Cisum")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 28)
                .background(.black.opacity(0.28))

                Spacer()

                HStack(spacing: 12) {
                    ForEach(["music.note", "folder", "gearshape", "app.badge"], id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 46, height: 46)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.bottom, 18)
            }
        }
        .background(Color.black)
    }
}

private struct CisumPlaybackControlLabel: View {
    let configuration: ButtonStyleConfiguration
    let reduceMotion: Bool

    @State private var isHovering = false

    private var hoverScale: CGFloat {
        isHovering && !reduceMotion ? 1.05 : 1.0
    }

    private var pressScale: CGFloat {
        configuration.isPressed && !reduceMotion ? LumiMotion.pressScale : 1.0
    }

    var body: some View {
        configuration.label
            .scaleEffect(hoverScale * pressScale)
            .animation(
                reduceMotion ? nil : LumiMotion.press,
                value: configuration.isPressed
            )
            .animation(
                reduceMotion ? nil : LumiMotion.hover,
                value: isHovering
            )
            #if os(macOS)
            .onHover { isHovering = $0 }
            #endif
    }
}

private struct CisumHoverScaleModifier: ViewModifier {
    let scale: CGFloat
    let duration: Double

    @State private var isHovering = false
    @LumiMotionPreferenceReader private var motionPreference

    init(scale: CGFloat, duration: Double = 0.2) {
        self.scale = scale
        self.duration = duration
    }

    func body(content: Content) -> some View {
        #if os(macOS)
            content
                .scaleEffect(isHovering && motionPreference.allowsMotion ? scale : 1.0)
                .animation(
                    LumiMotion.enabled(.easeOut(duration: duration), preference: motionPreference),
                    value: isHovering
                )
                .onHover { hovering in
                    LumiMotion.animate(LumiMotion.enabled(.easeOut(duration: duration), preference: motionPreference)) {
                        isHovering = hovering
                    }
                }
        #else
            content
        #endif
    }
}

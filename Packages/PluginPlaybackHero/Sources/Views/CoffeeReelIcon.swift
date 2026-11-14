import SwiftUI

/// Cisum 的品牌图标：一枚俯视的咖啡滤杯。
///
/// 纯代码绘制，不依赖图片资源，因此在任意尺寸下都保持清晰。构图按
/// GeometryReader 给出的短边等比推导：杯盘 → 杯身 → 咖啡液面依次缩放，
/// 液面用 `destinationOut` 挖出四颗糖粒与中心气孔。
private struct CoffeeReelIcon: View {
    /// 杯身倾角。0 表示把手朝正右方，正值顺时针旋转。
    var handleRotation: Double = 30
    /// 是否填充品牌渐变底色；false 时只画杯子本身，便于叠在已有封面上。
    var useDefaultBackground: Bool = true
    var plateColor: Color = .white

    private let showBrownCircle = true
    private let cupColor = Color(red: 0.8, green: 0.6, blue: 0.2)

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let plateSize = size * 0.6
            let cupSize = plateSize * 0.8
            let brewSize = cupSize
            let sugarSize = brewSize * 0.5
            let sugarDotSize = sugarSize * 0.5
            let sugarOffset = sugarSize * 0.5
            let centerDotSize = sugarDotSize * 0.6
            let handleWidth = cupSize * 0.16
            let handleLength = cupSize * 0.7

            ZStack {
                if useDefaultBackground {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.2, green: 0.5, blue: 0.4),
                            Color(red: 0.2, green: 0.5, blue: 0.7),
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color.clear
                }

                // 杯盘与把手：用 mask 挖出中空，阴影让盘子浮起来。
                Circle()
                    .stroke(plateColor, lineWidth: plateSize - cupSize)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 3)
                    .frame(width: plateSize, height: plateSize)
                    .mask {
                        Circle()
                            .stroke(.white, lineWidth: plateSize - cupSize)
                            .frame(width: plateSize, height: plateSize)
                            .overlay {
                                Capsule()
                                    .frame(width: handleLength, height: handleWidth)
                                    .offset(x: cupSize * 0.3)
                                    .rotationEffect(.degrees(handleRotation))
                                    .shadow(color: .black.opacity(0.3), radius: 3, x: 2, y: 2)
                                    .blendMode(.destinationOut)
                            }
                    }

                // 杯身。
                Circle()
                    .fill(Color.clear)
                    .stroke(cupColor, lineWidth: cupSize * 0.15)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)
                    .frame(width: cupSize, height: cupSize)

                if showBrownCircle {
                    // 咖啡液面，挖出四颗糖粒与中心气孔。
                    Circle()
                        .fill(Color(red: 0.35, green: 0.22, blue: 0.17))
                        .frame(width: brewSize, height: brewSize)
                        .mask {
                            Circle()
                                .fill(Color.white)
                                .frame(width: brewSize, height: brewSize)
                                .overlay {
                                    ZStack {
                                        ForEach(0 ..< 4) { index in
                                            Circle()
                                                .frame(width: sugarDotSize, height: sugarDotSize)
                                                .offset(
                                                    x: sugarOffset * cos(Double(index) * .pi / 2),
                                                    y: sugarOffset * sin(Double(index) * .pi / 2)
                                                )
                                                .blendMode(.destinationOut)
                                        }

                                        Circle()
                                            .frame(width: centerDotSize, height: centerDotSize)
                                            .blendMode(.destinationOut)
                                    }
                                }
                        }
                }
            }
        }
    }
}

extension Image {
    /// 播放器在缺少真实封面时使用的品牌占位图。
    ///
    /// - Parameters:
    ///   - useDefaultBackground: 是否填充品牌渐变底色。叠在已有封面上时传 `false`。
    ///   - plateColor: 杯盘颜色。
    ///   - handleRotation: 杯把倾角，单位为度。
    ///   - size: 固定尺寸；`nil` 表示跟随父视图的提议尺寸。
    static func coffeeReelIcon(
        useDefaultBackground: Bool = true,
        plateColor: Color = .white,
        handleRotation: Double = 30,
        size: CGFloat? = nil
    ) -> some View {
        CoffeeReelIcon(
            handleRotation: handleRotation,
            useDefaultBackground: useDefaultBackground,
            plateColor: plateColor
        )
        .frame(width: size, height: size)
    }
}

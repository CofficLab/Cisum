import SwiftUI
import Combine

// MARK: - Avatar View Shape
/// 头像视图的形状类型
public enum AvatarViewShape: Shape {
    /// 圆形
    case circle
    /// 矩形
    case rectangle
    /// 圆角矩形
    case roundedRectangle(cornerRadius: CGFloat)
    /// 胶囊形状
    case capsule
    /// 八边形
    case octagon
    /// 六边形
    case hexagon
    /// 五边形
    case pentagon

    /// 生成形状路径
    /// - Parameter rect: 形状的边界矩形
    /// - Returns: 形状的路径
    public func path(in rect: CGRect) -> Path {
        switch self {
        case .circle:
            return Circle().path(in: rect)
        case .rectangle:
            return Rectangle().path(in: rect)
        case .roundedRectangle(let cornerRadius):
            return RoundedRectangle(cornerRadius: cornerRadius).path(in: rect)
        case .capsule:
            return Capsule().path(in: rect)
        case .octagon:
            var path = Path()
            let side = min(rect.width, rect.height)
            let offset = side * 0.29 // 约 30% 的偏移量使八边形更美观
            
            path.move(to: CGPoint(x: rect.minX + offset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - offset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + offset))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - offset))
            path.addLine(to: CGPoint(x: rect.maxX - offset, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + offset, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - offset))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + offset))
            path.closeSubpath()
            return path
            
        case .hexagon:
            var path = Path()
            let side = min(rect.width, rect.height)
            let offset = side * 0.25
            
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - offset, y: rect.height * 0.25))
            path.addLine(to: CGPoint(x: rect.maxX - offset, y: rect.height * 0.75))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + offset, y: rect.height * 0.75))
            path.addLine(to: CGPoint(x: rect.minX + offset, y: rect.height * 0.25))
            path.closeSubpath()
            return path
            
        case .pentagon:
            var path = Path()
            let side = min(rect.width, rect.height)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = side / 2
            
            for i in 0..<5 {
                let angle = CGFloat(i) * 2 * .pi / 5 - .pi / 2
                let point = CGPoint(
                    x: center.x + radius * cos(angle),
                    y: center.y + radius * sin(angle)
                )
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
            return path
        }
    }

    /// 获取边框形状
    @ViewBuilder
    func strokeBorder(color: Color = .red, lineWidth: CGFloat = 1) -> some View {
        let style = StrokeStyle(lineWidth: lineWidth)
        switch self {
        case .circle:
            Circle().stroke(color, style: style)
        case .rectangle:
            Rectangle().stroke(color, style: style)
        case .roundedRectangle(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius).stroke(color, style: style)
        case .capsule:
            Capsule().stroke(color, style: style)
        case .octagon:
            self.path(in: .init(x: 0, y: 0, width: 100, height: 100))
                .stroke(color, style: style)
        case .hexagon:
            self.path(in: .init(x: 0, y: 0, width: 100, height: 100))
                .stroke(color, style: style)
        case .pentagon:
            self.path(in: .init(x: 0, y: 0, width: 100, height: 100))
                .stroke(color, style: style)
        }
    }
}


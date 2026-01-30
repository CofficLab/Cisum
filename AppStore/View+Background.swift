import SwiftUI
import MagicKit

// MARK: - View Extension for Background Decorations

extension View {
    /// 为视图添加装饰性背景元素
    /// - Returns: 带有装饰背景的视图
    func withPosterDecorations() -> some View {
        self.background {
            GeometryReader { geo in
                ZStack {
                    // 左上角大圆形装饰
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.08), .purple.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: geo.size.width * 0.4, height: geo.size.width * 0.4)
                        .position(x: geo.size.width * 0.15, y: geo.size.height * 0.2)

                    // 右下角大圆形装饰
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.06), .blue.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: geo.size.width * 0.5, height: geo.size.width * 0.5)
                        .position(x: geo.size.width * 0.8, y: geo.size.height * 0.75)

                    // 左下角小圆形装饰
                    Circle()
                        .fill(Color.blue.opacity(0.06))
                        .frame(width: geo.size.width * 0.2, height: geo.size.width * 0.2)
                        .position(x: geo.size.width * 0.2, y: geo.size.height * 0.8)

                    // 右上角小圆形装饰
                    Circle()
                        .fill(Color.purple.opacity(0.06))
                        .frame(width: geo.size.width * 0.15, height: geo.size.width * 0.15)
                        .position(x: geo.size.width * 0.85, y: geo.size.height * 0.15)

                    // 中央淡的音符装饰
                    Image(systemName: "music.note")
                        .font(.system(size: geo.size.width * 0.15))
                        .foregroundColor(.blue.opacity(0.05))
                        .position(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
                        .rotationEffect(.degrees(15))

                    // 左侧淡的音符装饰
                    Image(systemName: "music.note.list")
                        .font(.system(size: geo.size.width * 0.08))
                        .foregroundColor(.purple.opacity(0.04))
                        .position(x: geo.size.width * 0.25, y: geo.size.height * 0.6)
                        .rotationEffect(.degrees(-10))
                }
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color.green.opacity(0.4),
                    Color.teal.opacity(0.3),
                    Color.mint.opacity(0.2),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(.black)
    }
}

// MARK: - Preview

#Preview("App Store Hero") {
    AppStoreHero()
        .inMagicContainer(.macBook13, scale: 0.4)
}

import MagicKit
import SwiftUI

struct AppStoreAlbumArt: View {
    var body: some View {
        Group {
            Group {
                Text("专辑封面")
                    .bold()
                    .font(.system(size: 100, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.bottom, 40)
                    .shadowSm()

                VStack(spacing: 16) {
                    AlbumFeatureItem(
                        icon: "photo.fill",
                        title: "高清封面",
                        description: "自动获取专辑封面，无需手动添加",
                        color: .purple
                    )
                    AlbumFeatureItem(
                        icon: "square.grid.3x3.fill",
                        title: "网格布局",
                        description: "整洁的网格展示，快速浏览专辑",
                        color: .pink
                    )
                    AlbumFeatureItem(
                        icon: "sparkles",
                        title: "毛玻璃效果",
                        description: "精美的毛玻璃质感，视觉享受",
                        color: .red
                    )
                    AlbumFeatureItem(
                        icon: "arrow.down.circle.fill",
                        title: "封面下载",
                        description: "自动下载并缓存，离线也能查看",
                        color: .orange
                    )
                }
                .padding(.vertical, 20)
            }
            .inMagicVStackCenter()

            Spacer(minLength: 100)

            ZStack {
                // 第二个 ContentView（背景）
                ContentLayout()
                    .showDetail()
                    .inRootView()
                    .inDemoMode()
                    .frame(width: Config.minWidth)
                    .frame(height: 650)
                    .background(.background.opacity(0.5))
                    .roundedLarge()
                    .rotation3DEffect(
                        .degrees(-3),
                        axis: (x: 0, y: 0, z: 1),
                        anchor: .bottomLeading,
                        perspective: 1.0
                    )
                    .offset(x: -60, y: -20)
                    .shadowSm()

                // 第一个 ContentView（前景）
                ContentLayout()
                    .hideDetail()
                    .inRootView()
                    .inDemoMode()
                    .frame(width: Config.minWidth)
                    .frame(height: 650)
                    .background(.background.opacity(0.5))
                    .roundedLarge()
                    .shadow3xl()
                    .rotation3DEffect(
                        .degrees(3),
                        axis: (x: 0, y: 0, z: 1),
                        anchor: .bottomLeading,
                        perspective: 1.0
                    )
                    .offset(x: 10, y: -20)
            }
        }
        .magicCentered()
        .withBackgroundDecorations()
        .background(
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.3),
                    Color.pink.opacity(0.25),
                    Color.red.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(.background)
    }
}

// MARK: - Album Feature Item

private struct AlbumFeatureItem: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .p4()
        .frame(width: 380)
        .background(.regularMaterial)
        .roundedMedium()
        .shadowSm()
    }
}

// MARK: - Preview

#Preview("App Store Album Art") {
    AppStoreAlbumArt()
        .inMagicContainer(.macBook13, scale: 1)
}

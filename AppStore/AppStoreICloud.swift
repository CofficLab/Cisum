import MagicKit
import SwiftUI

struct AppStoreICloud: View {
    var body: some View {
        Group {
            Group {
                Text("iCloud 云同步")
                    .bold()
                    .font(.system(size: 100, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.bottom, 40)
                    .shadowSm()

                VStack(spacing: 16) {
                    ICFeatureItem(
                        icon: "icloud",
                        title: "云端同步",
                        description: "音乐库实时同步，随时随地访问",
                        color: .blue
                    )
                    ICFeatureItem(
                        icon: "ipad.and.iphone",
                        title: "多设备同步",
                        description: "iPhone、iPad、Mac 数据无缝流转",
                        color: .cyan
                    )
                    ICFeatureItem(
                        icon: "shield",
                        title: "安全备份",
                        description: "自动备份到 iCloud，数据永不丢失",
                        color: .teal
                    )
                    ICFeatureItem(
                        icon: "arrow.clockwise",
                        title: "自动同步",
                        description: "添加或修改后自动同步，无需手动操作",
                        color: .mint
                    )
                }
                .padding(.vertical, 20)
                .shadowSm()
            }
            .inMagicVStackCenter()

            Spacer(minLength: 100)

            ContentView()
                .inRootView()
                .inDemoMode()
                .frame(width: Config.minWidth)
                .frame(height: 650)
                .roundedLarge()
                .shadowSm()
        }
        .magicCentered()
        .withBackgroundDecorations()
        .background(
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.3),
                    Color.cyan.opacity(0.2),
                    Color.teal.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - ICFeature Item

private struct ICFeatureItem: View {
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
        .padding(16)
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("App Store iCloud") {
    AppStoreICloud()
        .inMagicContainer(.macBook13, scale: 1)
}

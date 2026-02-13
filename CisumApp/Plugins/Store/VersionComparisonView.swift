import MagicKit
import SwiftUI

/// 版本对比视图：展示免费版与专业版的区别
struct VersionComparisonView: View {
    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                Text("解锁完整体验", tableName: "Store")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .padding(.bottom, 12)

            // 对比卡片
            HStack(spacing: 12) {
                // 免费版卡片
                VersionCard(
                    title: String(localized: "免费版", table: "Store"),
                    icon: "person.fill",
                    color: .gray,
                    features: [
                        ("maxAudioCount", String(localized: "最多 \(AudioPlugin.maxAudioCount) 首音频", table: "Store"), "music.note"),
                    ],
                    isPro: false
                )

                // 专业版卡片
                VersionCard(
                    title: String(localized: "专业版", table: "Store"),
                    icon: "crown.fill",
                    color: .blue,
                    features: [
                        ("unlimited", String(localized: "无限制音频", table: "Store"), "infinity"),
                        ("future", String(localized: "未来新功能优先体验", table: "Store"), "star.fill"),
                        ("support", String(localized: "支持我们做得更好", table: "Store"), "heart.fill"),
                    ],
                    isPro: true
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - 版本卡片

private struct VersionCard: View {
    let title: String
    let icon: String
    let color: Color
    let features: [(String, String, String)]
    let isPro: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题区域
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(
                        isPro
                            ? LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [.gray.opacity(0.6), .gray.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                    )
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(isPro ? .primary : .secondary)
                }
            }

            Divider()
                .background(.gray.opacity(0.2))

            // 功能列表
            VStack(alignment: .leading, spacing: 8) {
                ForEach(features, id: \.0) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: feature.2)
                            .font(.caption)
                            .foregroundStyle(isPro ? color : .secondary)
                            .frame(width: 16)

                        Text(feature.1)
                            .font(.caption)
                            .foregroundStyle(isPro ? .primary : .secondary)
                            .lineLimit(2)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(isPro ? 0.1 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(isPro ? 0.3 : 0.15), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("VersionComparisonView") {
    VersionComparisonView()
        .padding()
        .background(.thickMaterial)
}

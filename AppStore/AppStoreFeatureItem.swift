import MagicKit
import SwiftUI

/// App Store 功能特性项视图
struct AppStoreFeatureItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.primary)
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
        .background(.regularMaterial)
        .roundedSmall()
        .shadowLg()
    }
}

// MARK: - Preview

#Preview("Features") {
    VStack(spacing: 16) {
        AppStoreFeatureItem(
            icon: "icloud",
            title: "云端同步",
            description: "音乐库实时同步，随时随地访问"
        )

        AppStoreFeatureItem(
            icon: "photo.fill",
            title: "高清封面",
            description: "自动获取专辑封面，无需手动添加"
        )
    }
    .padding()
}

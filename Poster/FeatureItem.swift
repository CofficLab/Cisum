import MagicKit
import SwiftUI

/// App Store 功能特性项视图
struct AppStoreFeatureItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 32) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.primary)
                .frame(width: 56)

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 64)
        .background(.regularMaterial)
        .roundedExtraLarge()
        .shadowMd()
    }
}

// MARK: - Preview

#Preview("App Store iCloud") {
    AppStoreICloud()
        .inMagicContainer(.macBook13, scale: 0.5)
}

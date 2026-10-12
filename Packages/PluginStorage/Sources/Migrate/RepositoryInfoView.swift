import CisumUIComponents
import LumiUI

import SwiftUI
import CisumProviderStorage

enum RepositoryInfoActionPolicy {
    static func canOpenInFinder(
        _ url: URL?,
        fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:)
    ) -> Bool {
        guard let url else { return false }
        guard url.isFileURL else { return false }
        return fileExists(url.path)
    }
}

struct RepositoryInfoView: View {
    @LumiTheme private var appTheme
    let isDesktop: Bool

    let title: String
    let location: StorageLocation?
    let url: URL?

    var body: some View {
        AppCard(
            style: .subtle,
            cornerRadius: DesignTokens.Radius.sm,
            padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0),
            showShadow: false
        ) {
            VStack(alignment: .leading, spacing: 0) {
                headerView

                if let url {
                    FileListView(
                        url: url,
                        expandByDefault: true
                    )
                    .frame(maxHeight: .infinity)
                    .padding(.top, DesignTokens.Spacing.xs)
                }
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.bodyEmphasized)
                .foregroundStyle(appTheme.textPrimary)
            Text(location?.emojiTitle ?? String(localized: "Not Set", bundle: .module))
                .font(DesignTokens.Typography.caption1)
                .foregroundStyle(appTheme.textSecondary)
            Spacer()

            if let root = url,
               isDesktop,
               RepositoryInfoActionPolicy.canOpenInFinder(root) {
                AppButton(systemImage: "arrow.up.forward.square", style: .ghost, size: .small) {
                    root.openFolder()
                }
                .accessibilityLabel(Text("Open Current Repository", bundle: .module))
                .help(String(localized: "Open Current Repository", bundle: .module))
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(appTheme.primary.opacity(0.1))
    }
}

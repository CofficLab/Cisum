import LumiUI

import MagicKit
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

    /// 「在文件管理器中打开」入口是否应展示。
    ///
    /// 三个条件缺一不可：
    /// 1. 平台支持（iOS 上打开沙盒目录必然失败）；
    /// 2. 目录确实存在；
    /// 3. 指向的是本地文件 URL。
    static func shouldOfferOpenEntry(
        _ url: URL?,
        supportsFileManager: Bool = URLOpenActionPolicy.shouldOfferFileManagerEntry,
        fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:)
    ) -> Bool {
        guard supportsFileManager else { return false }
        return canOpenInFinder(url, fileExists: fileExists)
    }
}

struct RepositoryInfoView: View {
    @LumiTheme private var appTheme

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
               RepositoryInfoActionPolicy.shouldOfferOpenEntry(root) {
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

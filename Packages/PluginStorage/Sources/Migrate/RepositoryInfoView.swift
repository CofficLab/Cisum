import CisumUIComponents

import SwiftUI

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
    let location: StoragePluginLocation?
    let url: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView

            if let url = url {
                VStack(spacing: 0) {
                    FileListView(
                        url: url,
                        expandByDefault: true
                    )
                    .frame(maxHeight: .infinity)
                }
                .background(Color.secondary.opacity(0.02))
                .cornerRadius(6)
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(location?.emojiTitle ?? String(localized: "Not Set", bundle: .module))
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()

            if let path = url?.path, isDesktop {
                Text(path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(path)
            }

            Spacer()

            if let root = url,
               isDesktop,
               RepositoryInfoActionPolicy.canOpenInFinder(root) {
                root.makeOpenButton()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(appTheme.primary.opacity(0.1))
        .cornerRadius(6)
    }
}

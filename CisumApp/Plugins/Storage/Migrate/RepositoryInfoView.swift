import MagicKit

import SwiftUI

struct RepositoryInfoView: View {
    let title: String
    let location: StorageLocation
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
            Spacer()

            if let path = url?.path, Config.isDesktop {
                Text(path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(path)
            }

            Spacer()

            if let root = url, Config.isDesktop {
                root.makeOpenButton()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(6)
    }
}

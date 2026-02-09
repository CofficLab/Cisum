import MagicKit

import SwiftUI

struct FileInfoView: View {
    let itemSize: Int64
    let downloadStatus: FileStatus.DownloadStatus?
    let isProcessing: Bool
    let showDownloadStatus: Bool

    init(
        itemSize: Int64,
        downloadStatus: FileStatus.DownloadStatus?,
        isProcessing: Bool,
        showDownloadStatus: Bool = false
    ) {
        self.itemSize = itemSize
        self.downloadStatus = downloadStatus
        self.isProcessing = isProcessing
        self.showDownloadStatus = showDownloadStatus
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(bytes)
        var unitIndex = 0

        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }

        return String(format: "%.1f %@", size, units[unitIndex])
    }

    var body: some View {
        HStack(spacing: 8) {
            // 状态描述
            if let status = downloadStatus, showDownloadStatus {
                Text(status.description)
                    .font(.caption)
                    .foregroundColor(status.color)
                    .frame(minWidth: 80, alignment: .trailing)
                    .transition(.opacity)
            }
            // 文件大小
            Text(formatFileSize(itemSize))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(minWidth: 60, alignment: .trailing)
        }
        .padding(.horizontal, 4)
        .background(
            isProcessing ?
                Color.accentColor.opacity(0.1) :
                Color.clear
        )
        .cornerRadius(4)
    }
}

#Preview {
    VStack(spacing: 16) {
        FileInfoView(
            itemSize: 1024 * 1024,
            downloadStatus: .downloading(progress: 0.5),
            isProcessing: true,
            showDownloadStatus: true
        )

        FileInfoView(
            itemSize: 2048 * 1024 * 1024,
            downloadStatus: .downloaded,
            isProcessing: false,
            showDownloadStatus: false
        )

        FileInfoView(
            itemSize: 3 * 1024 * 1024 * 1024,
            downloadStatus: .directoryStatus(
                total: 10,
                downloaded: 5,
                downloading: 2,
                notDownloaded: 3
            ),
            isProcessing: false,
            showDownloadStatus: true
        )
    }
    .padding()
}

import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

extension MagicPlayManPreviewView {
    /// 下载进度视图
    func downloadingProgress(_ progress: Double, title: String) -> some View {
        let normalizedProgress = PlaybackState.normalizedDownloadProgress(progress)

        return VStack(spacing: 16) {
            ProgressView(
                "\(playMan.localization.downloading) \(title)",
                value: normalizedProgress,
                total: 1.0
            )
            Text(PlaybackState.downloadPercentText(for: progress))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// 加载指示器视图
    func loadingIndicator(_ message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayManPreviewView()
        .frame(width: 600, height: 700)
}

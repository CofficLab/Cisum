import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

extension MagicPlayManPreviewView {
    /// 加载状态覆盖层
    func LoadingOverlay(state: PlaybackState.LoadingState, assetTitle: String) -> some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            switch state {
            case let .downloading(progress):
                downloadingProgress(progress, title: assetTitle)
            case .buffering:
                loadingIndicator(playMan.localization.buffering)
            case .preparing:
                loadingIndicator(playMan.localization.preparing)
            case .connecting:
                loadingIndicator(playMan.localization.connecting)
            }
        }
    }

    /// 错误覆盖层
    func ErrorOverlay(error: PlaybackState.PlaybackError, asset: URL, onRetry: @escaping () -> Void) -> some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)

                Text(playMan.localization.failedToLoadMedia)
                    .font(.headline)

                Text(error.localizedDescription(localization: playMan.localization))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: onRetry) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text(playMan.localization.tryAgain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.blue, in: Capsule())
                    .foregroundStyle(.white)
                }
            }
            .padding()
        }
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayManPreviewView()
        .frame(width: 600, height: 700)
}

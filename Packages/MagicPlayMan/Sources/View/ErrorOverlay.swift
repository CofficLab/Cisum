import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

struct ErrorOverlay: View {
    let error: PlaybackState.PlaybackError
    let asset: MagicAsset
    let onRetry: () -> Void

    @Environment(\.localization) private var loc

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)

                Text(loc.failedToLoadMedia)
                    .font(.headline)

                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: onRetry) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text(loc.tryAgain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }

    private var errorMessage: String {
        switch error {
        case .noAsset:
            return loc.noMediaSelected
        case .invalidAsset:
            return loc.invalidOrCorrupted
        case let .networkError(message):
            return "\(loc.networkError): \(message)"
        case let .playbackError(message):
            return "\(loc.playbackError): \(message)"
        case let .unsupportedFormat(ext):
            return "\(loc.unsupportedFormat): \(ext)"
        case let .invalidURL(url):
            return "\(loc.invalidURL): \(url)"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ErrorOverlay(
            error: .invalidAsset,
            asset: .init(url: .documentsDirectory, metadata: .init(title: "Test")),
            onRetry: {}
        )
        .frame(height: 200)

        ErrorOverlay(
            error: .networkError("Connection timeout"),
            asset: .init(url: .documentsDirectory, metadata: .init(title: "Test")),
            onRetry: {}
        )
        .frame(height: 200)
    }
    .padding()
}

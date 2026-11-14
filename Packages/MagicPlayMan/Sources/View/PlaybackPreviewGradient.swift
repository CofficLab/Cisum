import SwiftUI

enum PlaybackPreviewGradient {
    static let aurora = LinearGradient(
        colors: [.green.opacity(0.35), .cyan.opacity(0.25), .purple.opacity(0.35)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let winter = LinearGradient(
        colors: [.blue.opacity(0.16), .mint.opacity(0.12), .white.opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

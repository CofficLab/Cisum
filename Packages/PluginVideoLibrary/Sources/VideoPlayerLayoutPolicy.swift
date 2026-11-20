import CoreGraphics
import Foundation

enum VideoPlayerLayoutPolicy {
    static func isHeroVisible(repositoryURL: URL?, itemCount: Int) -> Bool {
        repositoryURL != nil && itemCount > 0
    }

    static func shouldRenderEmbeddedPlayer(hasAsset: Bool, isPlayerPresented: Bool) -> Bool {
        hasAsset && !isPlayerPresented
    }

    static func playerSize(in availableSize: CGSize, aspectRatio: CGFloat = 16.0 / 9.0) -> CGSize {
        guard availableSize.width > 0, availableSize.height > 0, aspectRatio > 0 else { return .zero }
        let width = min(availableSize.width, availableSize.height * aspectRatio)
        return CGSize(width: width, height: width / aspectRatio)
    }
}

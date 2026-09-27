import Foundation
import CisumUIComponents
import LumiUI

enum AudioDeletePlaybackPolicy {
    static func deletedURLsContainCurrentAudio(currentURL: URL?, deletedURLs: [URL]) -> Bool {
        guard let currentURL else { return false }
        return deletedURLs.contains { deletedURL in
            currentURL.isSameFileLocation(as: deletedURL)
        }
    }

    static func shouldResetDirectlyAfterDelete(
        currentURL: URL?,
        deletedURLs: [URL],
        isPlaybackControllerHandlingDeletion: Bool
    ) -> Bool {
        !isPlaybackControllerHandlingDeletion && deletedURLsContainCurrentAudio(
            currentURL: currentURL,
            deletedURLs: deletedURLs
        )
    }

}

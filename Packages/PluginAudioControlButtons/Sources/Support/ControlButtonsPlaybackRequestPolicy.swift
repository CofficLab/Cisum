import Foundation

enum ControlButtonsPlaybackRequestPolicy {
    static func shouldApplyNavigationResult(
        requestedAsset: URL,
        currentAsset: URL?,
        isSceneActive: Bool,
        currentGeneration: Int = 0,
        requestGeneration: Int = 0
    ) -> Bool {
        currentGeneration == requestGeneration
            && isSceneActive
            && representsSameFile(requestedAsset, currentAsset)
    }

    static func shouldReportNavigationFailure(
        requestedAsset: URL,
        currentAsset: URL?,
        isSceneActive: Bool,
        currentGeneration: Int = 0,
        requestGeneration: Int = 0
    ) -> Bool {
        shouldApplyNavigationResult(
            requestedAsset: requestedAsset,
            currentAsset: currentAsset,
            isSceneActive: isSceneActive,
            currentGeneration: currentGeneration,
            requestGeneration: requestGeneration
        )
    }

    static func currentAssetAffectedByDeletion(currentAsset: URL?, deletedURLs: [URL]) -> Bool {
        guard let currentAsset else { return false }
        return deletedURLs.contains { currentAsset.isSameFileLocation(as: $0) }
    }

    static func shouldApplyDeletionRecovery(
        currentAsset: URL?,
        deletedURLs: [URL],
        currentGeneration: Int = 0,
        requestGeneration: Int = 0
    ) -> Bool {
        currentGeneration == requestGeneration
            && currentAssetAffectedByDeletion(currentAsset: currentAsset, deletedURLs: deletedURLs)
    }

    static func shouldResetForStorageLocationChange(isSceneActive: Bool) -> Bool {
        isSceneActive
    }

    static func shouldApplyStorageReset(
        currentGeneration: Int,
        requestGeneration: Int,
        isSceneActive: Bool
    ) -> Bool {
        currentGeneration == requestGeneration && isSceneActive
    }

    static func generationAfterDeactivation(_ generation: Int) -> Int {
        generation + 1
    }

    private static func representsSameFile(_ lhs: URL?, _ rhs: URL?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case let (.some(lhs), .some(rhs)):
            return lhs.isSameFileLocation(as: rhs)
        default:
            return false
        }
    }
}

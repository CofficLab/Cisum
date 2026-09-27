import AVFoundation
import Foundation
import CisumUIComponents
import LumiUI
import OSLog
import ProviderAudioLibrary
import ProviderAudioLike
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

enum AudioProgressPersistencePolicy {
    static func shouldPersistWhenSceneChanges(from oldSceneName: String?, to newSceneName: String?, audioSceneName: String) -> Bool {
        oldSceneName == audioSceneName && newSceneName != audioSceneName
    }

    static func currentURLToStore(_ url: URL?, storedURL: URL?, supportedExtensions: [String]) -> URL? {
        guard let url else { return nil }

        let supportedExtensions = Set(supportedExtensions.map { $0.lowercased() })
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            return storedURL
        }

        return url
    }

    static func shouldResetGlobalTimeWhenCurrentURLChanges(from storedURL: URL?, to newURL: URL?) -> Bool {
        !representsSameFile(storedURL, newURL)
    }

    static func shouldClearRestoredCurrentURL(storedURL: URL?, isPlayable: Bool) -> Bool {
        storedURL != nil && !isPlayable
    }

    static func shouldClearRestoredCurrentTime(storedURL: URL?, isPlayable: Bool) -> Bool {
        shouldClearRestoredCurrentURL(storedURL: storedURL, isPlayable: isPlayable)
    }

    static func shouldClearStoredCurrentAfterDelete(storedURL: URL?, deletedURLs: [URL]) -> Bool {
        guard let storedURL else { return false }
        return deletedURLs.contains { deletedURL in
            storedURL.isSameFileLocation(as: deletedURL)
        }
    }

    static func shouldApplyRestoreResult(startingAsset: URL?, currentAsset: URL?) -> Bool {
        representsSameFile(startingAsset, currentAsset)
    }

    static func shouldApplyRestoreRequest(currentGeneration: Int, requestGeneration: Int, isSceneActive: Bool) -> Bool {
        currentGeneration == requestGeneration && isSceneActive
    }

    static func shouldPlayRestoredAsset(restoredAsset: URL, currentAsset: URL?) -> Bool {
        !representsSameFile(restoredAsset, currentAsset)
    }

    static func shouldApplyCurrentURLChange(requestedURL: URL?, currentAsset: URL?) -> Bool {
        representsSameFile(requestedURL, currentAsset)
    }

    static func shouldApplyCurrentURLChange(
        requestedURL: URL?,
        currentAsset: URL?,
        currentGeneration: Int,
        requestGeneration: Int,
        isSceneActive: Bool
    ) -> Bool {
        currentGeneration == requestGeneration
            && isSceneActive
            && shouldApplyCurrentURLChange(requestedURL: requestedURL, currentAsset: currentAsset)
    }

    static func shouldApplyWidgetMetadataResult(requestedAsset: URL, currentAsset: URL?) -> Bool {
        representsSameFile(requestedAsset, currentAsset)
    }

    static func shouldApplyWidgetClearResult(currentAsset: URL?) -> Bool {
        currentAsset == nil
    }

    static func representsSameFile(_ lhs: URL?, _ rhs: URL?) -> Bool {
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

public struct AudioProgressRootView<Content>: View where Content: View {
    @ObservedObject private var viewModel: AudioProgressViewModel

    private var content: Content

    init(
        viewModel: AudioProgressViewModel,
        @ViewBuilder content: () -> Content
    ) {
        self.viewModel = viewModel
        self.content = content()
    }

    public var body: some View {
        content
    }
}

import Foundation
import CisumUIComponents
import OSLog
import ProviderBook
import ProviderBook
import SwiftUI

public typealias BookProgressURLProvider = @MainActor () -> URL?
public typealias BookProgressTimeProvider = @MainActor () -> TimeInterval?
public typealias BookProgressStoreCurrentURL = @MainActor (URL?) -> Void
public typealias BookProgressStoreCurrentTime = @MainActor (TimeInterval) -> Void
public typealias BookProgressDiskProvider = @MainActor () -> URL?
public typealias BookProgressSaveBookState = @MainActor @Sendable (URL, URL, TimeInterval?) async -> Void

enum BookProgressSaveTrigger {
    case currentURLChanged
    case playbackPositionChanged
}

struct BookProgressStateSnapshot: Equatable {
    let currentURL: URL
    let time: TimeInterval?
}

enum BookProgressPersistencePolicy {
    static func currentURLChangeSnapshot(currentURL: URL?) -> BookProgressStateSnapshot? {
        guard let currentURL else { return nil }

        return BookProgressStateSnapshot(currentURL: currentURL, time: nil)
    }

    static func shouldClearRestoredCurrentURL(currentURL: URL?, isPlayable: Bool) -> Bool {
        currentURL != nil && !isPlayable
    }

    static func shouldClearRestoredCurrentTime(currentURL: URL?, isPlayable: Bool) -> Bool {
        shouldClearRestoredCurrentURL(currentURL: currentURL, isPlayable: isPlayable)
    }

    static func shouldClearStoredCurrentAfterDelete(storedURL: URL?, deletedURLs: [URL]) -> Bool {
        guard let storedURL else { return false }
        let storedPaths = BookProgressFileLocationIdentity.containmentPaths(for: storedURL)
        return deletedURLs.contains { deletedURL in
            BookProgressFileLocationIdentity.containmentPaths(for: deletedURL).contains { deletedPath in
                storedPaths.contains { storedPath in
                    storedPath == deletedPath
                        || storedPath.hasPrefix(BookProgressPathContainment.childPrefix(for: deletedPath))
                }
            }
        }
    }

    static func shouldResetGlobalTimeWhenCurrentURLChanges(from storedURL: URL?, to newURL: URL?) -> Bool {
        !representsSameFile(storedURL, newURL)
    }

    static func shouldPersistCurrentURLChange(from storedURL: URL?, to newURL: URL?) -> Bool {
        !representsSameFile(storedURL, newURL)
    }

    static func shouldAcceptBookURL(_ url: URL, bookDisk: URL?) -> Bool {
        BookProgressBookLookup.bookURL(for: url, bookDisk: bookDisk) != nil
    }

    static func shouldPersistPlaybackProgress(currentURL: URL?, bookDisk: URL?) -> Bool {
        guard let currentURL else { return false }

        return shouldAcceptBookURL(currentURL, bookDisk: bookDisk)
    }

    static func snapshot(currentURL: URL?, currentTime: TimeInterval, trigger: BookProgressSaveTrigger) -> BookProgressStateSnapshot? {
        guard let currentURL else { return nil }

        switch trigger {
        case .currentURLChanged:
            return currentURLChangeSnapshot(currentURL: currentURL)
        case .playbackPositionChanged:
            return BookProgressStateSnapshot(currentURL: currentURL, time: normalizedPlaybackTime(currentTime))
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

    static func shouldApplyCurrentURLChange(requestedURL: URL, currentAsset: URL?) -> Bool {
        representsSameFile(requestedURL, currentAsset)
    }

    static func shouldApplyCurrentURLChange(
        requestedURL: URL,
        currentAsset: URL?,
        currentGeneration: Int,
        requestGeneration: Int,
        isSceneActive: Bool
    ) -> Bool {
        currentGeneration == requestGeneration
            && isSceneActive
            && shouldApplyCurrentURLChange(requestedURL: requestedURL, currentAsset: currentAsset)
    }

    private static func representsSameFile(_ lhs: URL?, _ rhs: URL?) -> Bool {
        BookProgressFileLocationIdentity.representsSameFile(lhs, rhs)
    }

    private static func normalizedPlaybackTime(_ time: TimeInterval) -> TimeInterval {
        guard time.isFinite, time > 0 else { return 0 }
        return time
    }
}

enum BookProgressFileLocationIdentity {
    static func representsSameFile(_ lhs: URL?, _ rhs: URL?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case let (.some(lhs), .some(rhs)):
            return stablePath(for: lhs) == stablePath(for: rhs)
        default:
            return false
        }
    }

    static func containmentPaths(for url: URL) -> Set<String> {
        if FileManager.default.fileExists(atPath: url.path) {
            return [
                url.standardizedFileURL.path,
                url.resolvingSymlinksInPath().standardizedFileURL.path,
            ]
        }

        return [url.standardizedFileURL.path]
    }

    private static func stablePath(for url: URL) -> String {
        if FileManager.default.fileExists(atPath: url.path) {
            return url.resolvingSymlinksInPath().standardizedFileURL.path
        }

        return url.standardizedFileURL.path
    }
}

enum BookProgressBookRootResolver {
    static func bookRoot(containing url: URL, bookDisk: URL?) -> URL {
        let parent = url.deletingLastPathComponent().standardizedFileURL

        guard let bookDisk else {
            return parent
        }

        let disk = bookDisk.standardizedFileURL
        let url = url.standardizedFileURL

        guard BookProgressPathContainment.resolved(url, isContainedIn: disk) else {
            return parent
        }

        guard isContained(url.path, in: disk.path) else {
            return mappedBookRoot(for: url, in: disk)
        }

        guard parent.path != disk.path else {
            return url
        }

        var candidate = parent
        while candidate.deletingLastPathComponent().standardizedFileURL.path != disk.path,
              isContained(candidate.path, in: disk.path) {
            candidate = candidate.deletingLastPathComponent().standardizedFileURL
        }

        return candidate
    }

    private static func mappedBookRoot(for url: URL, in disk: URL) -> URL {
        let resolvedURLPath = BookProgressPathContainment.resolvedStandardizedPath(for: url)
        let resolvedDiskPath = BookProgressPathContainment.resolvedStandardizedPath(for: disk)

        guard let relativePath = BookProgressPathContainment.relativePath(of: resolvedURLPath, in: resolvedDiskPath),
              !relativePath.isEmpty else {
            return disk
        }

        guard let topLevelComponent = relativePath.split(separator: "/", omittingEmptySubsequences: true).first else {
            return disk
        }

        let isDirectory = relativePath.contains("/")
        return disk.appendingPathComponent(String(topLevelComponent), isDirectory: isDirectory).standardizedFileURL
    }

    private static func isContained(_ childPath: String, in parentPath: String) -> Bool {
        childPath == parentPath || childPath.hasPrefix(BookProgressPathContainment.childPrefix(for: parentPath))
    }
}

enum BookProgressBookLookup {
    static func bookURL(for currentURL: URL, bookDisk: URL?) -> URL? {
        if let bookDisk, !BookProgressPathContainment.resolved(currentURL, isContainedIn: bookDisk) {
            return nil
        }

        let bookURL = BookProgressBookRootResolver.bookRoot(containing: currentURL, bookDisk: bookDisk)

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: bookURL.path, isDirectory: &isDirectory) else {
            return nil
        }

        if isDirectory.boolValue {
            return bookURL
        }

        return BookPluginInfo.supportedExtensions.contains(bookURL.pathExtension.lowercased()) ? bookURL : nil
    }

}

enum BookProgressPathContainment {
    static func resolved(_ child: URL, isContainedIn parent: URL) -> Bool {
        isContained(resolvedStandardizedPath(for: child), in: resolvedStandardizedPath(for: parent))
    }

    static func resolvedStandardizedPath(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    static func relativePath(of childPath: String, in parentPath: String) -> String? {
        if childPath == parentPath {
            return ""
        }

        let prefix = childPrefix(for: parentPath)
        guard childPath.hasPrefix(prefix) else {
            return nil
        }

        return String(childPath.dropFirst(prefix.count))
    }

    private static func isContained(_ childPath: String, in parentPath: String) -> Bool {
        childPath == parentPath || childPath.hasPrefix(childPrefix(for: parentPath))
    }

    static func childPrefix(for parentPath: String) -> String {
        parentPath.hasSuffix("/") ? parentPath : parentPath + "/"
    }
}

public struct BookProgressRootView<Content>: View where Content: View {
    @ObservedObject private var viewModel: BookProgressViewModel

    private let content: Content

    init(
        viewModel: BookProgressViewModel,
        @ViewBuilder content: () -> Content
    ) {
        self.viewModel = viewModel
        self.content = content()
    }

    public var body: some View {
        content
    }
}

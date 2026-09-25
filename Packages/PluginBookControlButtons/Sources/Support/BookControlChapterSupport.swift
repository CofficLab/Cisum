import Foundation
import CisumUIComponents
import MagicPlayMan
import OSLog
import ProviderBook
import SwiftUI

enum BookControlBookRootResolver {
    static func bookRoot(containing url: URL, bookDisk: URL?) -> URL {
        let parent = url.deletingLastPathComponent().standardizedFileURL

        guard let bookDisk else {
            return parent
        }

        let disk = bookDisk.standardizedFileURL
        let url = url.standardizedFileURL

        guard BookControlPathContainment.resolved(url, isContainedIn: disk) else {
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
        let resolvedURLPath = BookControlPathContainment.resolvedStandardizedPath(for: url)
        let resolvedDiskPath = BookControlPathContainment.resolvedStandardizedPath(for: disk)

        guard let relativePath = BookControlPathContainment.relativePath(of: resolvedURLPath, in: resolvedDiskPath),
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
        childPath == parentPath || childPath.hasPrefix(parentPath.hasSuffix("/") ? parentPath : parentPath + "/")
    }
}

enum BookControlPathContainment {
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

        let prefix = parentPath.hasSuffix("/") ? parentPath : parentPath + "/"
        guard childPath.hasPrefix(prefix) else {
            return nil
        }

        return String(childPath.dropFirst(prefix.count))
    }

    private static func isContained(_ childPath: String, in parentPath: String) -> Bool {
        childPath == parentPath || childPath.hasPrefix(parentPath.hasSuffix("/") ? parentPath : parentPath + "/")
    }
}

enum BookControlFileLocationIdentity {
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

enum BookControlPlaybackRequestPolicy {
    static func shouldNavigateBookAsset(_ asset: URL, bookDisk: URL?) -> Bool {
        guard let bookDisk else { return true }
        return BookControlPathContainment.resolved(asset, isContainedIn: bookDisk)
    }

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

    static func currentAssetAffectedByDeletion(currentAsset: URL?, deletedURLs: [URL]) -> Bool {
        guard let currentAsset else { return false }
        let assetPaths = BookControlFileLocationIdentity.containmentPaths(for: currentAsset)
        return deletedURLs.contains { deletedURL in
            BookControlFileLocationIdentity.containmentPaths(for: deletedURL).contains { parentPath in
                assetPaths.contains { assetPath in
                    isContained(assetPath, in: parentPath)
                }
            }
        }
    }

    static func shouldApplyDeletionReset(
        currentAsset: URL?,
        deletedURLs: [URL],
        currentGeneration: Int,
        requestGeneration: Int
    ) -> Bool {
        currentGeneration == requestGeneration
            && currentAssetAffectedByDeletion(currentAsset: currentAsset, deletedURLs: deletedURLs)
    }

    static func shouldInvalidateChapterCacheAfterDeletion(deletedURLs: [URL]) -> Bool {
        !deletedURLs.isEmpty
    }

    static func shouldInvalidateChapterCacheAfterLibraryRefresh() -> Bool {
        true
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
        BookControlFileLocationIdentity.representsSameFile(lhs, rhs)
    }

    private static func isContained(_ childPath: String, in parentPath: String) -> Bool {
        childPath == parentPath || childPath.hasPrefix(parentPath.hasSuffix("/") ? parentPath : parentPath + "/")
    }
}

enum BookControlChapterLoader {
    static func relativePath(_ url: URL, in root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path

        guard isContained(path, in: rootPath) else {
            return url.lastPathComponent
        }

        return String(path.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func isContained(_ path: String, in rootPath: String) -> Bool {
        path == rootPath || path.hasPrefix(rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
    }

    static func playableChapters(in root: URL) -> [URL] {
        let scanRoot = root.isFolder ? root : root.resolvingSymlinksInPath().standardizedFileURL

        return playableFiles(in: scanRoot)
            .map { mappedURL($0, from: scanRoot, to: root) }
            .sorted {
                relativePath($0, in: root).localizedStandardCompare(relativePath($1, in: root)) == .orderedAscending
            }
    }

    private static func playableFiles(in root: URL) -> [URL] {
        guard root.isFolder else {
            return isPlayableFile(root) ? [root] : []
        }

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let url as URL in enumerator {
            guard !url.isFolder, isPlayableFile(url) else { continue }
            files.append(url)
        }

        return files
    }

    private static func isPlayableFile(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
            && BookPluginInfo.supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private static func mappedURL(_ url: URL, from scanRoot: URL, to root: URL) -> URL {
        let scanRootPath = scanRoot.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        let urlPath = url.standardizedFileURL.path

        guard scanRootPath != rootPath,
              let relativePath = BookControlPathContainment.relativePath(of: urlPath, in: scanRootPath) else {
            return url
        }

        return root.appendingPathComponent(relativePath).standardizedFileURL
    }

    static func adjacentAsset(
        in chapters: [URL],
        current asset: URL,
        offset: Int,
        playMode: MagicPlayMode
    ) -> URL? {
        guard !chapters.isEmpty,
              let index = chapters.firstIndex(where: { isSameFile($0, asset) }) else { return nil }

        let adjacentIndex = index + offset
        if chapters.indices.contains(adjacentIndex) {
            return chapters[adjacentIndex]
        }

        switch playMode {
        case .repeatAll:
            return offset > 0 ? chapters.first : chapters.last
        case .shuffle:
            return shuffleCandidates(in: chapters, current: asset).randomElement() ?? chapters.first
        case .sequence, .loop:
            return nil
        }
    }

    static func shuffleCandidates(in chapters: [URL], current asset: URL) -> [URL] {
        chapters.filter { !isSameFile($0, asset) }
    }

    private static func isSameFile(_ lhs: URL, _ rhs: URL) -> Bool {
        BookControlFileLocationIdentity.representsSameFile(lhs, rhs)
    }
}

@MainActor
enum BookControlChapterCache {
    private static var chaptersByRoot: [String: [URL]] = [:]

    static func cachedChapters(in root: URL) -> [URL]? {
        chaptersByRoot[cacheKey(for: root)]
    }

    static func store(_ chapters: [URL], in root: URL) {
        chaptersByRoot[cacheKey(for: root)] = chapters
    }

    static func removeAll() {
        chaptersByRoot.removeAll()
    }

    private static func cacheKey(for root: URL) -> String {
        if FileManager.default.fileExists(atPath: root.path) {
            return root.resolvingSymlinksInPath().standardizedFileURL.path
        }

        return root.standardizedFileURL.path
    }
}
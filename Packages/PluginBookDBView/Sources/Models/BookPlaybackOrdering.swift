import Foundation
import CisumUIComponents
import ProviderBook
import ProviderBook

enum BookPlaybackOrdering {
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

    static func playableChildren(for root: URL) -> [URL] {
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
              let relativePath = relativePath(of: urlPath, in: scanRootPath) else {
            return url
        }

        return root.appendingPathComponent(relativePath).standardizedFileURL
    }

    private static func relativePath(of childPath: String, in parentPath: String) -> String? {
        if childPath == parentPath {
            return ""
        }

        let prefix = parentPath.hasSuffix("/") ? parentPath : parentPath + "/"
        guard childPath.hasPrefix(prefix) else {
            return nil
        }

        return String(childPath.dropFirst(prefix.count))
    }

    static func contains(_ url: URL, in urls: [URL]) -> Bool {
        urls.contains { representsSameFile($0, url) }
    }

    static func containsPlayableChild(_ url: URL, in root: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path),
              BookPluginInfo.supportedExtensions.contains(url.pathExtension.lowercased()) else {
            return false
        }

        return isContained(stablePath(for: url), in: stablePath(for: root))
    }

    static func representsSameFile(_ lhs: URL, _ rhs: URL) -> Bool {
        stablePath(for: lhs) == stablePath(for: rhs)
    }

    private static func stablePath(for url: URL) -> String {
        if FileManager.default.fileExists(atPath: url.path) {
            return url.resolvingSymlinksInPath().standardizedFileURL.path
        }

        return url.standardizedFileURL.path
    }
}

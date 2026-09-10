import Foundation
import ProviderBook

enum BookPathContainment {
    static func representsSameFile(_ lhs: URL, _ rhs: URL) -> Bool {
        canonicalIdentity(for: lhs) == canonicalIdentity(for: rhs)
    }

    static func canonicalIdentity(for url: URL) -> String {
        guard url.isFileURL else {
            return url.standardized.absoluteString
        }

        if !FileManager.default.fileExists(atPath: url.path) {
            return url.standardizedFileURL.path
        }

        return resolvedStandardizedPath(for: url)
    }

    static func hasSameResolvedParent(_ url: URL, as parent: URL) -> Bool {
        let resolvedParent = resolvedStandardizedPath(for: url.deletingLastPathComponent())
        return resolvedParent == resolvedStandardizedPath(for: parent)
    }

    static func contains(_ parent: URL, child: URL) -> Bool {
        containsPath(
            parent: resolvedStandardizedPath(for: parent),
            child: resolvedStandardizedPath(for: child)
        ) || containsPath(
            parent: parent.standardizedFileURL.path,
            child: child.standardizedFileURL.path
        )
    }

    private static func resolvedStandardizedPath(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private static func containsPath(parent: String, child: String) -> Bool {
        child == parent || child.hasPrefix(childPrefix(for: parent))
    }

    private static func childPrefix(for parentPath: String) -> String {
        parentPath.hasSuffix("/") ? parentPath : parentPath + "/"
    }
}

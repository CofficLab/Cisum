import MagicKit
import Foundation
import CisumUIComponents
import LumiUI
import OSLog

typealias ProgressCallback = (Double, String) -> Void
typealias DownloadProgressCallback = (String, FileStatus.DownloadStatus) -> Void

class MigrationManager: ObservableObject, SuperLog, SuperThread, @unchecked Sendable {
    static let emoji: String = "👵"

    private let cancellationLock = NSLock()
    private var cancellationRequested = false

    var isCancelled: Bool {
        cancellationLock.lock()
        let value = cancellationRequested
        cancellationLock.unlock()
        return value
    }

    func cancelMigration() {
        cancellationLock.lock()
        cancellationRequested = true
        cancellationLock.unlock()
    }

    func resetCancellation() {
        cancellationLock.lock()
        cancellationRequested = false
        cancellationLock.unlock()
    }

    func migrate(
        from sourceRoot: URL,
        to targetRoot: URL,
        progressCallback: ProgressCallback?,
        downloadProgressCallback: DownloadProgressCallback?,
        verbose: Bool
    ) throws {
        os_log(.info, "\(self.t)Starting migration task")

        let targetRootExistedBeforeMigration = FileManager.default.fileExists(atPath: targetRoot.path)

        do {
            if Self.resolvedStandardizedPath(for: sourceRoot) == Self.resolvedStandardizedPath(for: targetRoot) {
                progressCallback?(1.0, "")
                os_log(.info, "\(self.t)Source and target directories are the same, skipping migration")
                return
            }
            guard !Self.isTargetNestedInSource(sourceRoot: sourceRoot, targetRoot: targetRoot) else {
                throw MigrationError.fileOperationFailed(String(localized: "Target folder cannot be inside the source folder", bundle: .module))
            }

            // Get all files and filter out .DS_Store.
            var files = try FileManager.default.contentsOfDirectory(
                at: sourceRoot,
                includingPropertiesForKeys: nil
            ).filter { $0.lastPathComponent != ".DS_Store" }

            files.sort { $0.lastPathComponent < $1.lastPathComponent }
            os_log(.info, "\(self.t)Found \(files.count) files to migrate, excluding .DS_Store")

            try FileManager.default.createDirectory(
                at: targetRoot,
                withIntermediateDirectories: true
            )
            os_log(.info, "\(self.t)Created target directory")

            guard !files.isEmpty else {
                progressCallback?(1.0, "")
                os_log(.info, "\(self.t)Source directory is empty, migration completed")
                return
            }

            for (index, sourceFile) in files.enumerated() {
                if self.isCancelled {
                    os_log(.info, "\(self.t)Migration task was canceled")
                    throw MigrationError.migrationCancelled
                }

                let fileName = sourceFile.lastPathComponent

                os_log(.info, "\(self.t)Migrating file: \(fileName) (\(index + 1)/\(files.count))")

                progressCallback?(Double(index) / Double(files.count), fileName)

                if self.isCancelled {
                    os_log(.info, "\(self.t)Migration task was canceled")
                    throw MigrationError.migrationCancelled
                }

                try prepareForMigration(
                    sourceFile,
                    downloadProgressCallback: downloadProgressCallback
                )

                if self.isCancelled {
                    os_log(.info, "\(self.t)Migration task was canceled")
                    throw MigrationError.migrationCancelled
                }

                let targetFile = uniqueDestination(for: sourceFile, in: targetRoot)
                do {
                    try migrateItem(from: sourceFile, to: targetFile)
                    os_log(.info, "\(self.t)Migrated successfully: \(fileName) -> \(targetFile.lastPathComponent)")
                    progressCallback?(Double(index + 1) / Double(files.count), fileName)
                } catch {
                    os_log(.error, "\(self.t)Migration failed: \(fileName) - \(error.localizedDescription)")
                    throw MigrationError.fileOperationFailed("\(fileName): \(error.localizedDescription)")
                }
            }

            if self.isCancelled {
                os_log(.info, "\(self.t)Migration task was canceled")
                throw MigrationError.migrationCancelled
            }

            os_log(.info, "\(self.t)Keeping source directory")
            os_log(.info, "\(self.t)Migration completed, processed \(files.count) files")
        } catch {
            os_log(.error, "\(self.t)Migration error: \(error.localizedDescription)")
            Self.removeEmptyTargetDirectoryCreatedForFailedMigration(
                targetRoot,
                targetRootExistedBeforeMigration: targetRootExistedBeforeMigration
            )
            if let migrationError = error as? MigrationError {
                throw migrationError
            } else {
                throw MigrationError.fileOperationFailed(error.localizedDescription)
            }
        }

        os_log(.info, "\(self.t)Migration task finished")
    }

    static func isTargetNestedInSource(sourceRoot: URL, targetRoot: URL) -> Bool {
        let sourcePath = resolvedStandardizedPath(for: sourceRoot)
        let targetPath = resolvedStandardizedPath(for: targetRoot)

        return targetPath != sourcePath && targetPath.hasPrefix(childPrefix(for: sourcePath))
    }

    private static func resolvedStandardizedPath(for url: URL) -> String {
        let fileManager = FileManager.default
        var existingAncestor = url
        var missingComponents: [String] = []

        while !fileManager.fileExists(atPath: existingAncestor.path),
              existingAncestor.path != existingAncestor.deletingLastPathComponent().path {
            missingComponents.insert(existingAncestor.lastPathComponent, at: 0)
            existingAncestor.deleteLastPathComponent()
        }

        var resolvedURL = existingAncestor.resolvingSymlinksInPath().standardizedFileURL
        for component in missingComponents {
            resolvedURL.appendPathComponent(component)
        }

        return resolvedURL.standardizedFileURL.path
    }

    private static func childPrefix(for parentPath: String) -> String {
        parentPath.hasSuffix("/") ? parentPath : parentPath + "/"
    }

    private static func removeEmptyTargetDirectoryCreatedForFailedMigration(
        _ targetRoot: URL,
        targetRootExistedBeforeMigration: Bool
    ) {
        guard !targetRootExistedBeforeMigration else {
            return
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: targetRoot.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              let contents = try? FileManager.default.contentsOfDirectory(at: targetRoot, includingPropertiesForKeys: nil),
              contents.isEmpty else {
            return
        }

        try? FileManager.default.removeItem(at: targetRoot)
    }

    private func prepareForMigration(
        _ sourceFile: URL,
        downloadProgressCallback: DownloadProgressCallback?
    ) throws {
        if sourceFile.isFolder {
            for child in fileDescendants(of: sourceFile) {
                try ensureLocalAvailability(
                    for: child,
                    displayName: sourceFile.lastPathComponent,
                    downloadProgressCallback: downloadProgressCallback
                )
            }
        } else {
            try ensureLocalAvailability(
                for: sourceFile,
                displayName: sourceFile.lastPathComponent,
                downloadProgressCallback: downloadProgressCallback
            )
        }
    }

    private func fileDescendants(of folder: URL) -> AnySequence<URL> {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return AnySequence([])
        }

        return AnySequence {
            AnyIterator {
                while let url = enumerator.nextObject() as? URL {
                    if !url.isFolder {
                        return url
                    }
                }

                return nil
            }
        }
    }

    private func ensureLocalAvailability(
        for url: URL,
        displayName: String,
        downloadProgressCallback: DownloadProgressCallback?
    ) throws {
        downloadProgressCallback?(displayName, .downloading(progress: url.getDownloadProgressSnapshot()))
        try url.ensureLocalAvailabilitySync()
        downloadProgressCallback?(displayName, .local)
    }

    private func migrateItem(from sourceFile: URL, to targetFile: URL) throws {
        let resolvedSource = sourceFile.resolvingSymlinksInPath().standardizedFileURL
        let standardizedSource = sourceFile.standardizedFileURL

        guard Self.representsSymlink(sourceFile),
              FileManager.default.fileExists(atPath: resolvedSource.path),
              resolvedSource.path != standardizedSource.path else {
            try FileManager.default.moveItem(at: sourceFile, to: targetFile)
            return
        }

        try FileManager.default.copyItem(at: resolvedSource, to: targetFile)
        try FileManager.default.removeItem(at: sourceFile)
    }

    private static func representsSymlink(_ url: URL) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
    }

    private func uniqueDestination(for sourceFile: URL, in targetRoot: URL) -> URL {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: sourceFile.path, isDirectory: &isDirectory)

        let sourceIsDirectory = isDirectory.boolValue
        let pathExtension = sourceIsDirectory ? "" : sourceFile.pathExtension
        let rawBaseName = sourceIsDirectory
            ? sourceFile.lastPathComponent
            : sourceFile.deletingPathExtension().lastPathComponent
        let baseName = rawBaseName.isEmpty ? "Migrated Item" : rawBaseName

        var candidate = destination(
            named: baseName,
            pathExtension: pathExtension,
            in: targetRoot,
            isDirectory: sourceIsDirectory
        )
        var suffix = 2

        while Self.pathExistsIncludingSymlink(candidate) {
            candidate = destination(
                named: "\(baseName) \(suffix)",
                pathExtension: pathExtension,
                in: targetRoot,
                isDirectory: sourceIsDirectory
            )
            suffix += 1
        }

        return candidate
    }

    private static func pathExistsIncludingSymlink(_ url: URL) -> Bool {
        if FileManager.default.fileExists(atPath: url.path) {
            return true
        }

        return (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
    }

    private func destination(
        named name: String,
        pathExtension: String,
        in directory: URL,
        isDirectory: Bool
    ) -> URL {
        let destination = directory.appendingPathComponent(name, isDirectory: isDirectory)
        guard !pathExtension.isEmpty else {
            return destination
        }

        return destination.appendingPathExtension(pathExtension)
    }
}

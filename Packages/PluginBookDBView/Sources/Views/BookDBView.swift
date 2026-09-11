import Foundation
import CisumUIComponents
import OSLog
import ProviderBook
import ProviderBook
import SwiftUI
import UniformTypeIdentifiers

// NSItemProvider is thread-safe by design but not yet marked Sendable by Apple.
extension NSItemProvider: @retroactive @unchecked Sendable {}

public struct BookDBView: View, SuperLog, SuperThread {
    public nonisolated static let emoji = "🐘"
    public nonisolated static let verbose = false
    
    private let dependencies: BookDBViewDependencies
    private let viewModel: BookGridViewModel
    @State private var isFileImporterPresented = false
    @State private var isImportingFiles = false
    @State private var isDropping = false
    @State var treeView = false
    
    /// Whether files are being dragged over the view.
    var dropping: Bool { isDropping }
    
    /// Whether to use the list view. Defaults to the grid view.
    private var useListView = false

    init(dependencies: BookDBViewDependencies, viewModel: BookGridViewModel) {
        self.dependencies = dependencies
        self.viewModel = viewModel
    }

    public var body: some View {
        if Self.verbose {
            os_log("\(self.t)📺 Rendering")
        }
        return VStack(spacing: 0) {
            if useListView {
                BookList(dependencies: dependencies, viewModel: viewModel)
            } else {
                BookGrid(
                    viewModel: viewModel,
                    dependencies: dependencies,
                    requestImport: { isFileImporterPresented = true }
                )
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.folder, .audio],
            allowsMultipleSelection: true,
            onCompletion: handleFileImport
        )
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropping, perform: handleDrop)
        .onAppear(perform: handleOnAppear)
    }
}

// MARK: - Action

extension BookDBView {
    /// Copies files to the repository.
    ///
    /// Copies selected or dropped files into the book repository.
    ///
    /// - Parameter files: File URLs to copy.
    func copy(_ files: [URL]) {
        if Self.verbose {
            os_log("\(self.t)📂 Preparing to copy \(files.count) files")
        }

        let importSources = Self.importableSourceCandidates(files)

        guard !importSources.isEmpty else {
            alert_error(String(localized: "No files were added", bundle: .module))
            return
        }

        guard let bookDisk = dependencies.bookDisk else {
            // os_log(.error, "\(self.t)❌ Book repository directory is unavailable")
            alert_error(String(localized: "Storage location is unavailable", bundle: .module))
            return
        }

        guard Self.shouldStartImport(isImporting: isImportingFiles) else {
            alert_warning(String(localized: "Import is already in progress", bundle: .module))
            return
        }

        if Self.shouldReportSkippedImportSources(files, importSources: importSources) {
            alert_warning(String(localized: "Some files were skipped because they are not supported audiobook sources", bundle: .module))
        }

        isImportingFiles = true
        Task {
            defer {
                isImportingFiles = false
            }

            var copiedItems: [URL] = []
            do {
                copiedItems = try await Task.detached(priority: .userInitiated) {
                    try await Self.copyImportedItems(importSources, to: bookDisk)
                }.value
                guard !copiedItems.isEmpty else {
                    alert_error(String(localized: "No files were added", bundle: .module))
                    return
                }

                guard let bookProvider = dependencies.bookProvider else {
                    alert_error(String(localized: "Book repository is unavailable", bundle: .module))
                    return
                }

                try await bookProvider.syncImportedItems(copiedItems)
            } catch {
                Self.cleanUpCopiedItems(copiedItems)
                // os_log(.error, "\(self.t)❌ Failed to copy book files: \(error.localizedDescription)")
                await MainActor.run {
                    alert_error(String(localized: "Import failed: \(error.localizedDescription)", bundle: .module))
                }
            }
        }
    }
}

// MARK: - Import Helpers

extension BookDBView {
    nonisolated static func copyImportedItems(_ files: [URL], to bookDisk: URL) async throws -> [URL] {
        try FileManager.default.createDirectory(at: bookDisk, withIntermediateDirectories: true)

        let importSources = uniqueImportSources(files)
        let folders = importSources.filter(Self.isFolderLikeImportSource)
        let audioFiles = importSources.filter { url in
            !Self.isFolderLikeImportSource(url) && BookPluginInfo.supportedExtensions.contains(url.pathExtension.lowercased())
        }
        var copiedItems: [URL] = []

        do {
            for folder in folders {
                guard try canImportFolder(folder) else { continue }

                let destination = uniqueDestination(for: folder, in: bookDisk)
                let sourceToCopy = copySourceURL(for: folder)
                guard !isDestinationNestedInSource(source: sourceToCopy, destination: destination) else {
                    throw NSError(
                        domain: "BookDBView",
                        code: 2,
                        userInfo: [
                            NSLocalizedDescriptionKey: String(localized: "Import destination cannot be inside the original folder", bundle: .module)
                        ]
                    )
                }
                try await copySecurityScopedItem(folder, to: destination)
                copiedItems.append(destination)
            }

            guard !audioFiles.isEmpty else { return copiedItems }

            let collectionName = audioFiles.count == 1 ? audioFiles[0].title : collectionTitle(for: audioFiles)
            let collectionURL = uniqueDestination(named: collectionName, in: bookDisk, isDirectory: true)
            try FileManager.default.createDirectory(at: collectionURL, withIntermediateDirectories: true)
            copiedItems.append(collectionURL)

            for file in audioFiles {
                let destination = uniqueDestination(for: file, in: collectionURL)
                try await copySecurityScopedItem(file, to: destination)
            }
        } catch {
            for copiedItem in copiedItems {
                try? FileManager.default.removeItem(at: copiedItem)
            }
            throw error
        }

        return copiedItems
    }

    nonisolated static func importableSourceCandidates(_ urls: [URL]) -> [URL] {
        uniqueImportSources(urls).filter { url in
            isFolderLikeImportSource(url)
                || BookPluginInfo.supportedExtensions.contains(url.pathExtension.lowercased())
        }
    }

    nonisolated static func shouldReportSkippedImportSources(_ urls: [URL], importSources: [URL]) -> Bool {
        uniqueImportSources(urls).count > importSources.count && !importSources.isEmpty
    }

    nonisolated static func cleanUpCopiedItems(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    nonisolated static func droppedFileURL(from provider: NSItemProvider) async throws -> URL? {
        var fileURLDataError: Error?

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            do {
                let data: Data? = try await withCheckedThrowingContinuation { continuation in
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: data)
                        }
                    }
                }

                if let data, let url = URL(dataRepresentation: data, relativeTo: nil), url.isFileURL {
                    return url
                }
            } catch {
                fileURLDataError = error
            }
        }

        if let url = try await droppedURLObject(from: provider) {
            return url
        }

        if let fileURLDataError {
            throw fileURLDataError
        }

        return nil
    }

    nonisolated private static func droppedURLObject(from provider: NSItemProvider) async throws -> URL? {
        guard provider.canLoadObject(ofClass: URL.self) else { return nil }

        return try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: object)
                }
            }
        }
    }

    nonisolated static func droppedFileURLs(from providers: [NSItemProvider]) async -> (urls: [URL], errors: [Error]) {
        var urls: [URL] = []
        var errors: [Error] = []

        for provider in providers {
            do {
                if let url = try await droppedFileURL(from: provider) {
                    urls.append(url)
                }
            } catch {
                errors.append(error)
            }
        }

        return (urls, errors)
    }

    nonisolated static func shouldImportDroppedURLs(_ urls: [URL], after errors: [Error]) -> Bool {
        !urls.isEmpty
    }

    nonisolated static func shouldReportDroppedURLLoadFailure(_ urls: [URL], errors: [Error]) -> Bool {
        urls.isEmpty && !errors.isEmpty
    }

    nonisolated static func shouldReportPartialDroppedURLLoadFailure(_ urls: [URL], errors: [Error]) -> Bool {
        !urls.isEmpty && !errors.isEmpty
    }

    nonisolated static func shouldStartImport(isImporting: Bool) -> Bool {
        !isImporting
    }

    nonisolated static func uniqueImportSources(_ urls: [URL]) -> [URL] {
        var seenIdentities = Set<String>()
        var uniqueURLs: [URL] = []
        uniqueURLs.reserveCapacity(urls.count)

        for url in urls {
            let identity = canonicalImportSourceIdentity(for: url)
            guard seenIdentities.insert(identity).inserted else {
                continue
            }

            uniqueURLs.append(url)
        }

        return uniqueURLs.filter { source in
            !isNestedInSelectedFolder(source, selectedSources: uniqueURLs)
        }
    }

    private nonisolated static func isNestedInSelectedFolder(_ source: URL, selectedSources: [URL]) -> Bool {
        selectedSources.contains { candidate in
            guard candidate != source, isFolderLikeImportSource(candidate) else {
                return false
            }

            return isDestinationNestedInSource(source: candidate, destination: source)
        }
    }

    nonisolated static func representsSameImportSource(_ lhs: URL, _ rhs: URL) -> Bool {
        canonicalImportSourceIdentity(for: lhs) == canonicalImportSourceIdentity(for: rhs)
    }

    nonisolated static func canonicalImportSourceIdentity(for url: URL) -> String {
        guard url.isFileURL else {
            return url.standardized.absoluteString
        }

        return resolvedStandardizedPath(for: url)
    }

    nonisolated static func isDestinationNestedInSource(source: URL, destination: URL) -> Bool {
        let sourcePath = resolvedStandardizedPath(for: source)
        let destinationPath = resolvedStandardizedPath(for: destination)

        return destinationPath != sourcePath && destinationPath.hasPrefix(childPrefix(for: sourcePath))
    }

    private nonisolated static func resolvedStandardizedPath(for url: URL) -> String {
        let standardizedURL = url.standardizedFileURL
        guard !FileManager.default.fileExists(atPath: standardizedURL.path) else {
            return standardizedURL.resolvingSymlinksInPath().standardizedFileURL.path
        }

        var candidate = standardizedURL
        var missingComponents: [String] = []
        while !FileManager.default.fileExists(atPath: candidate.path) {
            let parent = candidate.deletingLastPathComponent()
            guard parent.path != candidate.path else {
                return standardizedURL.resolvingSymlinksInPath().standardizedFileURL.path
            }
            missingComponents.insert(candidate.lastPathComponent, at: 0)
            candidate = parent
        }

        var resolvedURL = candidate.resolvingSymlinksInPath().standardizedFileURL
        for component in missingComponents {
            resolvedURL.appendPathComponent(component)
        }
        return resolvedURL.standardizedFileURL.path
    }

    private nonisolated static func childPrefix(for parentPath: String) -> String {
        parentPath.hasSuffix("/") ? parentPath : parentPath + "/"
    }

    nonisolated static func hasImportSourceAccess(_ source: URL, securityScopeGranted: Bool) -> Bool {
        securityScopeGranted || FileManager.default.isReadableFile(atPath: source.path)
    }

    nonisolated static func isFolderLikeImportSource(_ source: URL) -> Bool {
        source.isFolder || resolvedDirectoryURL(for: source) != nil
    }

    private nonisolated static func resolvedDirectoryURL(for source: URL) -> URL? {
        let resolvedURL = source.resolvingSymlinksInPath().standardizedFileURL
        return resolvedURL.isFolder ? resolvedURL : nil
    }

    private nonisolated static func copySourceURL(for source: URL) -> URL {
        if source.isFolder {
            return source
        }

        if let resolvedDirectory = resolvedDirectoryURL(for: source) {
            return resolvedDirectory
        }

        let resolvedSource = source.resolvingSymlinksInPath().standardizedFileURL
        guard FileManager.default.fileExists(atPath: resolvedSource.path) else {
            return source
        }

        return resolvedSource
    }

    private nonisolated static func canImportFolder(_ folder: URL) throws -> Bool {
        let hasAccess = folder.startAccessingSecurityScopedResource()
        guard hasImportSourceAccess(folder, securityScopeGranted: hasAccess) else {
            throw NSError(
                domain: "BookDBView",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "Permission to access the original file was denied", bundle: .module)
                ]
            )
        }

        defer {
            if hasAccess {
                folder.stopAccessingSecurityScopedResource()
            }
        }

        return folderContainsPlayableFiles(folder)
    }

    nonisolated static func folderContainsPlayableFiles(_ folder: URL) -> Bool {
        let source = copySourceURL(for: folder)
        for child in fileDescendants(of: source) {
            if isPlayableBookFile(child) {
                return true
            }
        }

        return false
    }

    private nonisolated static func isPlayableBookFile(_ url: URL) -> Bool {
        BookPluginInfo.supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private nonisolated static func fileDescendants(of folder: URL) -> AnySequence<URL> {
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

    private nonisolated static func copySecurityScopedItem(_ source: URL, to destination: URL) async throws {
        let hasAccess = source.startAccessingSecurityScopedResource()
        guard hasImportSourceAccess(source, securityScopeGranted: hasAccess) else {
            throw NSError(
                domain: "BookDBView",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "Permission to access the original file was denied", bundle: .module)
                ]
            )
        }

        defer {
            if hasAccess {
                source.stopAccessingSecurityScopedResource()
            }
        }

        let sourceToCopy = copySourceURL(for: source)
        if sourceToCopy.isFolder {
            for child in fileDescendants(of: sourceToCopy) {
                try await child.ensureLocalAvailability()
            }
        } else {
            try await sourceToCopy.ensureLocalAvailability()
        }

        try FileManager.default.copyItem(at: sourceToCopy, to: destination)
    }

    private nonisolated static func collectionTitle(for files: [URL]) -> String {
        let parents = Set(files.map { $0.deletingLastPathComponent() })
        guard parents.count == 1, let parent = parents.first, !parent.lastPathComponent.isEmpty else {
            return "Imported Audiobook"
        }
        return parent.lastPathComponent
    }

    private nonisolated static func uniqueDestination(for source: URL, in directory: URL) -> URL {
        uniqueDestination(
            named: source.deletingPathExtension().lastPathComponent,
            pathExtension: isFolderLikeImportSource(source) ? "" : source.pathExtension,
            in: directory,
            isDirectory: isFolderLikeImportSource(source)
        )
    }

    private nonisolated static func uniqueDestination(
        named name: String,
        pathExtension: String = "",
        in directory: URL,
        isDirectory: Bool
    ) -> URL {
        let baseName = name.isEmpty ? "Imported Audiobook" : name
        var candidate = destination(
            named: baseName,
            pathExtension: pathExtension,
            in: directory,
            isDirectory: isDirectory
        )
        var suffix = 2

        while pathExistsIncludingSymlink(candidate) {
            candidate = destination(
                named: "\(baseName) \(suffix)",
                pathExtension: pathExtension,
                in: directory,
                isDirectory: isDirectory
            )
            suffix += 1
        }

        return candidate
    }

    private nonisolated static func pathExistsIncludingSymlink(_ url: URL) -> Bool {
        if FileManager.default.fileExists(atPath: url.path) {
            return true
        }

        return (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private nonisolated static func destination(
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

// MARK: - Event Handler

extension BookDBView {
    /// Handles view appearance.
    ///
    /// Triggered when the view first appears on screen, and can run initialization work.
    func handleOnAppear() {
        if Self.verbose {
            os_log("\(self.t)👀 View appeared")
        }
        
        // TODO: Initialization can run here, for example:
        // - Check data integrity
        // - Load cached data
        // - Update statistics
    }
    
    /// Handles file import results.
    ///
    /// Triggered after the user imports files through the file picker.
    ///
    /// - Parameter result: File import result containing selected file URLs or error information.
    func handleFileImport(_ result: Result<[URL], Error>) {
        if Self.verbose {
            os_log("\(self.t)📥 Handling file import")
        }
        
        switch result {
        case let .success(urls):
            if Self.verbose {
                os_log("\(self.t)✅ Imported \(urls.count) files")
            }
            copy(urls)
            
        case let .failure(error):
            // os_log(.error, "\(self.t)❌ File import failed: \(error.localizedDescription)")
            alert_error(String(localized: "Import failed: \(error.localizedDescription)", bundle: .module))
        }
    }
    
    
    /// Handles file drop events.
    ///
    /// Triggered when the user drops files onto the view, then asynchronously loads all dropped file URLs and copies them.
    ///
    /// ## Flow
    /// 1. Create a DispatchGroup to coordinate all asynchronous loads.
    /// 2. Iterate through all providers and asynchronously load file URLs.
    /// 3. Collect all successfully loaded files.
    /// 4. Call copy on the main thread to copy them in a batch.
    ///
    /// - Parameter providers: Dropped providers, each containing one file reference.
    /// - Returns: Always returns `true` to accept the drop.
    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        if Self.verbose {
            os_log("\(self.t)🎯 Handling file drop, provider count: \(providers.count)")
        }

        Task {
            let droppedFiles = await Self.droppedFileURLs(from: providers)

            if Self.shouldReportDroppedURLLoadFailure(droppedFiles.urls, errors: droppedFiles.errors),
               let error = droppedFiles.errors.first {
                // os_log(.error, "\(self.t)⚠️ Failed to load file: \(error.localizedDescription)")
                alert_error(String(localized: "Import failed: \(error.localizedDescription)", bundle: .module))
            } else if Self.shouldReportPartialDroppedURLLoadFailure(droppedFiles.urls, errors: droppedFiles.errors) {
                // os_log(.error, "\(self.t)⚠️ Some dropped files failed to load")
                alert_warning(String(localized: "Some dropped files could not be loaded", bundle: .module))
            }

            guard Self.shouldImportDroppedURLs(droppedFiles.urls, after: droppedFiles.errors) else {
                return
            }

            copy(droppedFiles.urls)
        }
        
        return true
    }
}

// MARK: - Preview

#if os(macOS)

#endif

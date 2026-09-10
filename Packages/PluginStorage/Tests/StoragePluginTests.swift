import Testing
@testable import PluginStorage
import Foundation

@Test func storagePluginInfoIsExposed() {
    #expect(StoragePluginInfo.titleKey == "Storage Settings")
    #expect(StoragePluginLocation.local.rawValue == "local")
    #expect(StoragePlugin.shouldRegister)
}

@Test func fileItemReportsDirectoryReadFailures() {
    let missingDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let item = FileItem(url: missingDirectory, level: 0, isExpanded: true)

    #expect(throws: Error.self) {
        _ = try item.children()
    }
}

@Test func fileListOnlyAppliesLatestVisibleItemsUpdate() {
    #expect(FileListUpdatePolicy.shouldApplyResult(
        currentGeneration: 2,
        resultGeneration: 2
    ))
    #expect(!FileListUpdatePolicy.shouldApplyResult(
        currentGeneration: 2,
        resultGeneration: 1
    ))
}

@Test func fileListRefreshesDirectoryCacheWhenExpandedAgain() {
    let folder = URL(fileURLWithPath: "/tmp/cisum-storage-file-list", isDirectory: true)
    let child = folder.appendingPathComponent("old.mp3")
    let cachedItems = [
        folder: [
            FileItem(url: child, level: 1, isExpanded: false)
        ]
    ]

    #expect(FileListView.cacheAfterExpansionChange(
        isExpanded: true,
        itemURL: folder,
        currentCache: cachedItems
    )[folder] == nil)

    #expect(FileListView.cacheAfterExpansionChange(
        isExpanded: false,
        itemURL: folder,
        currentCache: cachedItems
    )[folder] == cachedItems[folder])
}

@Test func fileListRootStateTracksChangedRepositoryURL() {
    let firstRoot = URL(fileURLWithPath: "/tmp/cisum-storage-file-list/first", isDirectory: true)
    let secondRoot = URL(fileURLWithPath: "/tmp/cisum-storage-file-list/second", isDirectory: true)

    let collapsed = FileListView.initialState(rootURL: firstRoot, expandByDefault: false)
    let expanded = FileListView.initialState(rootURL: secondRoot, expandByDefault: true)

    #expect(collapsed.visibleItems.map(\.url) == [firstRoot])
    #expect(collapsed.expandedItems.isEmpty)
    #expect(expanded.visibleItems.map(\.url) == [secondRoot])
    #expect(expanded.expandedItems.contains(FileItem(url: secondRoot, level: 0, isExpanded: true)))
    #expect(!expanded.expandedItems.contains(FileItem(url: firstRoot, level: 0, isExpanded: true)))
}

@Test func fileExpandButtonAccessibilityLabelMatchesState() {
    #expect(FileExpandButtonAccessibilityPolicy.label(isExpanded: false) == "Expand folder")
    #expect(FileExpandButtonAccessibilityPolicy.label(isExpanded: true) == "Collapse folder")
}

@Test func fileInfoCellsOnlyApplyCurrentURLResults() {
    let first = URL(fileURLWithPath: "/tmp/cisum-storage-file-info/first")
    let second = URL(fileURLWithPath: "/tmp/cisum-storage-file-info/second")

    #expect(FileInfoCellLoadPolicy.shouldApplyResult(currentURL: first, requestedURL: first))
    #expect(!FileInfoCellLoadPolicy.shouldApplyResult(currentURL: second, requestedURL: first))
}

@Test func fileInfoCellsApplySymlinkedCurrentURLResults() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realFile = root.appendingPathComponent("real.mp3")
    let linkedFile = root.appendingPathComponent("linked.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: realFile)
    try FileManager.default.createSymbolicLink(at: linkedFile, withDestinationURL: realFile)

    #expect(FileInfoCellLoadPolicy.shouldApplyResult(
        currentURL: realFile,
        requestedURL: linkedFile
    ))
}

@Test func fileInfoCellsDoNotApplyResultsAcrossDistinctDanglingSymlinks() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingFile = root.appendingPathComponent("missing.mp3")
    let firstLink = root.appendingPathComponent("first.mp3")
    let secondLink = root.appendingPathComponent("second.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: firstLink, withDestinationURL: missingFile)
    try FileManager.default.createSymbolicLink(at: secondLink, withDestinationURL: missingFile)

    #expect(!FileInfoCellLoadPolicy.shouldApplyResult(
        currentURL: secondLink,
        requestedURL: firstLink
    ))
}

@Test func fileSizeReadPolicyReadsFoundationNumberAttributes() {
    #expect(FileSizeReadPolicy.fileSize(from: [.size: NSNumber(value: 1234)]) == 1234)
    #expect(FileSizeReadPolicy.fileSize(from: [.size: Int64(5678)]) == 5678)
    #expect(FileSizeReadPolicy.fileSize(from: [:]) == 0)
}

@Test func fileSizeReadPolicyNormalizesNegativeAttributes() {
    #expect(FileSizeReadPolicy.fileSize(from: [.size: NSNumber(value: -1234)]) == 0)
    #expect(FileSizeReadPolicy.fileSize(from: [.size: Int64(-5678)]) == 0)
    #expect(FileSizeReadPolicy.normalizedFileSize(-1) == 0)
}

@Test func fileSizeCalculationStreamsDirectoryFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let nested = root.appendingPathComponent("nested", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try Data(repeating: 1, count: 10).write(to: root.appendingPathComponent("first.bin"))
    try Data(repeating: 2, count: 15).write(to: nested.appendingPathComponent("second.bin"))
    try Data(repeating: 3, count: 50).write(to: root.appendingPathComponent(".hidden"))

    #expect(FileSizeCalculationPolicy.size(for: root) == 25)
}

@Test func fileSizeCalculationReadsSingleFileSize() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let file = root.appendingPathComponent("track.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data(repeating: 1, count: 12).write(to: file)

    #expect(FileSizeCalculationPolicy.size(for: file) == 12)
}

@Test func fileStatusReportsMissingLocalFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let existingFile = root.appendingPathComponent("track.mp3")
    let missingFile = root.appendingPathComponent("missing.mp3")
    let danglingLink = root.appendingPathComponent("dangling.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: existingFile)
    try FileManager.default.createSymbolicLink(
        at: danglingLink,
        withDestinationURL: root.appendingPathComponent("deleted-target.mp3")
    )

    #expect(FileStatusColumnView.resolveStatus(for: existingFile, verbose: false).status == "Local File")
    #expect(FileStatusColumnView.resolveStatus(for: missingFile, verbose: false).status == "Missing")
    #expect(FileStatusColumnView.resolveStatus(for: danglingLink, verbose: false).status == "Local File")
}

@Test func fileStatusDownloadPercentTextIsClamped() {
    #expect(FileStatus.DownloadStatus.percentText(for: .nan) == "0%")
    #expect(FileStatus.DownloadStatus.percentText(for: -.infinity) == "0%")
    #expect(FileStatus.DownloadStatus.percentText(for: -0.3) == "0%")
    #expect(FileStatus.DownloadStatus.percentText(for: 0.42) == "42%")
    #expect(FileStatus.DownloadStatus.percentText(for: 1.4) == "100%")
    #expect(FileStatus.DownloadStatus.downloading(progress: 1.4).description == "Downloading 100%")
}

@Test func fileStatusDirectoryScanIgnoresLocalDirectoriesAndHiddenFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let nested = root.appendingPathComponent("nested", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: root.appendingPathComponent("track.mp3"))
    try Data("hidden".utf8).write(to: root.appendingPathComponent(".hidden"))
    try Data("audio".utf8).write(to: nested.appendingPathComponent("nested.mp3"))

    #expect(FileStatusDirectoryScanPolicy.cloudDownloadStats(in: root).downloaded == 0)
    #expect(FileStatusDirectoryScanPolicy.cloudDownloadStats(in: root).notDownloaded == 0)
    #expect(FileStatusColumnView.resolveStatus(for: root, verbose: false).status == "Local Folder")
}

@Test func repositoryInfoOnlyOpensExistingLocalPaths() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingRoot = root.appendingPathComponent("missing", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    #expect(RepositoryInfoActionPolicy.canOpenInFinder(root))
    #expect(!RepositoryInfoActionPolicy.canOpenInFinder(missingRoot))
    #expect(!RepositoryInfoActionPolicy.canOpenInFinder(nil))
    #expect(!RepositoryInfoActionPolicy.canOpenInFinder(URL(string: "https://example.com")!))
}

@Test func directStorageSwitchUsesAccurateCompletionMessage() {
    #expect(MigrationProgressView.completionMessageKey(shouldMigrate: true) == "Migration completed")
    #expect(MigrationProgressView.completionMessageKey(shouldMigrate: false) == "Switched to new location")
    #expect(MigrationProgressView.completionMessage(shouldMigrate: true).isEmpty == false)
    #expect(MigrationProgressView.completionMessage(shouldMigrate: false).isEmpty == false)
}

@Test func migrationWarningTextUsesEnglishResourceKeys() {
    #expect(MigrationProgressView.migrationWarningTitleKey == "Important:")
    #expect(MigrationProgressView.migrationWarningICloudKey.hasPrefix("• If source data is in iCloud"))
    #expect(MigrationProgressView.migrationWarningDoNotCloseKey.hasPrefix("• Do not close the app"))
    #expect(MigrationProgressView.migrationWarningMigrateKey == "• Migrate Data: Move existing data to the new location")
    #expect(MigrationProgressView.migrationWarningUseDirectlyKey == "• Use Directly: Use the new location and keep existing data unchanged")
    #expect(MigrationProgressView.migrationWarningCancelKey == "• Cancel: Keep the original location unchanged")
}

@Test func migrationErrorAlertUsesEnglishRecoveryGuidance() {
    let message = MigrationProgressView.errorAlertMessage(
        errorMessage: "Permission denied",
        migrationCancelled: false
    )

    #expect(message.contains("Permission denied"))
    #expect(message.contains("The storage location has been reset to the original location"))
    #expect(message.contains("Recommended next steps:"))
    #expect(message.contains("Retry the migration"))
    #expect(!message.contains("Some files may already have been migrated"))
}

@Test func migrationErrorAlertIncludesCancellationRecoveryNote() {
    let message = MigrationProgressView.errorAlertMessage(
        errorMessage: "Cancelled",
        migrationCancelled: true
    )

    #expect(message.contains("Some files may already have been migrated to the new location."))
}

@Test func migrationErrorAlertFallsBackForBlankErrors() {
    let message = MigrationProgressView.errorAlertMessage(
        errorMessage: "  ",
        migrationCancelled: false
    )

    #expect(message.hasPrefix("Unknown error"))
}

@Test func storageSettingsClearsDisplayedSelectionAfterReset() {
    #expect(StorageSettingView.targetLocationAfterStorageUpdate(
        currentTarget: .icloud,
        storageLocation: .local
    ) == .local)
    #expect(StorageSettingView.targetLocationAfterStorageUpdate(
        currentTarget: .icloud,
        storageLocation: nil
    ) == .icloud)
    #expect(!StorageSettingView.hasSelectionChanges(
        targetLocation: .icloud,
        storageLocation: nil
    ))
    #expect(StorageSettingView.hasSelectionChanges(
        targetLocation: .icloud,
        storageLocation: .local
    ))
    #expect(!StorageSettingView.hasSelectionChanges(
        targetLocation: .local,
        storageLocation: .local
    ))
}

@Test func storageSettingsSyncsTargetAfterExternalLocationChange() {
    let changed = StorageSettingView.stateAfterStorageUpdate(
        currentTarget: .icloud,
        storageLocation: .local
    )
    #expect(changed.targetLocation == .local)
    #expect(!changed.hasChanges)

    let reset = StorageSettingView.stateAfterStorageUpdate(
        currentTarget: .icloud,
        storageLocation: nil
    )
    #expect(reset.targetLocation == .icloud)
    #expect(!reset.hasChanges)
}

@Test func migrationProgressOnlyAppliesCurrentGenerationUpdates() {
    #expect(MigrationProgressView.shouldApplyMigrationUpdate(
        currentGeneration: 2,
        updateGeneration: 2
    ))
    #expect(!MigrationProgressView.shouldApplyMigrationUpdate(
        currentGeneration: 3,
        updateGeneration: 2
    ))
}

@Test func migrationProgressNormalizesInvalidValues() {
    #expect(MigrationProgressView.normalizedMigrationProgress(.nan) == 0)
    #expect(MigrationProgressView.normalizedMigrationProgress(.infinity) == 0)
    #expect(MigrationProgressView.normalizedMigrationProgress(-0.2) == 0)
    #expect(MigrationProgressView.normalizedMigrationProgress(0.4) == 0.4)
    #expect(MigrationProgressView.normalizedMigrationProgress(1.4) == 1)
}

@Test func migrationStatusUpdatePreservesDownloadStateOnFailure() {
    let files = [
        FileStatus(name: "track.mp3", status: .processing, downloadStatus: .downloading(progress: 0.4))
    ]

    let updated = MigrationProgressView.processedFilesAfterStatusUpdate(
        files,
        fileName: "track.mp3",
        sourceURL: nil,
        error: "failed"
    )

    #expect(updated.count == 1)
    #expect(updated[0].status == .failed("failed"))
    #expect(updated[0].downloadStatus == .downloading(progress: 0.4))
}

@Test func migrationStatusUpdateCompletesOnlyAfterSourceFileLeaves() {
    let source = URL(fileURLWithPath: "/tmp/cisum-storage-source", isDirectory: true)
    let files = [
        FileStatus(name: "track.mp3", status: .pending, downloadStatus: .downloaded)
    ]

    let processing = MigrationProgressView.processedFilesAfterStatusUpdate(
        files,
        fileName: "track.mp3",
        sourceURL: source,
        fileExists: { $0.hasSuffix("/track.mp3") }
    )
    #expect(processing[0].status == .processing)
    #expect(processing[0].downloadStatus == .downloaded)

    let completed = MigrationProgressView.processedFilesAfterStatusUpdate(
        files,
        fileName: "track.mp3",
        sourceURL: source,
        fileExists: { _ in false }
    )
    #expect(completed[0].status == .completed)
    #expect(completed[0].downloadStatus == .local)
}

@Test func migrationStatusUpdateIgnoresUnknownFiles() {
    let files = [
        FileStatus(name: "track.mp3", status: .pending, downloadStatus: .local)
    ]

    let statusUpdated = MigrationProgressView.processedFilesAfterStatusUpdate(
        files,
        fileName: "missing.mp3",
        sourceURL: nil
    )
    let downloadUpdated = MigrationProgressView.processedFilesAfterDownloadStatusUpdate(
        files,
        fileName: "missing.mp3",
        downloadStatus: .downloaded
    )

    #expect(statusUpdated[0].name == "track.mp3")
    #expect(statusUpdated[0].status == .pending)
    #expect(statusUpdated[0].downloadStatus == .local)
    #expect(downloadUpdated[0].status == .pending)
    #expect(downloadUpdated[0].downloadStatus == .local)
}

@Test func migrationSheetOnlyDisablesDismissWhileRunning() {
    #expect(!MigrationProgressView.shouldDisableInteractiveDismiss(
        showConfirmation: true,
        migrationCompleted: false,
        migrationCancelled: false,
        errorMessage: nil
    ))
    #expect(MigrationProgressView.shouldDisableInteractiveDismiss(
        showConfirmation: false,
        migrationCompleted: false,
        migrationCancelled: false,
        errorMessage: nil
    ))
    #expect(!MigrationProgressView.shouldDisableInteractiveDismiss(
        showConfirmation: false,
        migrationCompleted: true,
        migrationCancelled: false,
        errorMessage: nil
    ))
    #expect(!MigrationProgressView.shouldDisableInteractiveDismiss(
        showConfirmation: false,
        migrationCompleted: false,
        migrationCancelled: true,
        errorMessage: nil
    ))
    #expect(!MigrationProgressView.shouldDisableInteractiveDismiss(
        showConfirmation: false,
        migrationCompleted: false,
        migrationCancelled: false,
        errorMessage: "failed"
    ))
}

@Test func missingSourceStorageDoesNotAttemptMigration() {
    let target = URL(fileURLWithPath: "/tmp/cisum-storage-target", isDirectory: true)

    #expect(!MigrationProgressView.shouldPerformMigration(
        sourceURL: nil,
        targetURL: target,
        requestedMigration: true
    ))
    #expect(!MigrationProgressView.shouldPerformMigration(
        sourceURL: target,
        targetURL: nil,
        requestedMigration: true
    ))
    #expect(!MigrationProgressView.shouldPerformMigration(
        sourceURL: target,
        targetURL: target,
        requestedMigration: false
    ))
    #expect(MigrationProgressView.shouldPerformMigration(
        sourceURL: target,
        targetURL: target,
        requestedMigration: true
    ))
}

@Test func migrationActionRequiresExistingSourceStorage() {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let missingSource = root.appendingPathComponent("missing", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }
    try? FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)

    #expect(MigrationProgressView.canMigrateExistingData(
        sourceLocation: .local,
        sourceURL: source
    ))
    #expect(!MigrationProgressView.canMigrateExistingData(
        sourceLocation: .local,
        sourceURL: missingSource
    ))
    #expect(!MigrationProgressView.canMigrateExistingData(
        sourceLocation: nil,
        sourceURL: source
    ))
    #expect(!MigrationProgressView.canMigrateExistingData(
        sourceLocation: .local,
        sourceURL: nil
    ))
}

@Test func migrationUsesDisplayedSourceAndTargetRoots() throws {
    let displayedSource = URL(fileURLWithPath: "/tmp/cisum-storage-displayed-source", isDirectory: true)
    let displayedTarget = URL(fileURLWithPath: "/tmp/cisum-storage-displayed-target", isDirectory: true)

    let roots = try MigrationProgressView.migrationRoots(
        sourceURL: displayedSource,
        targetURL: displayedTarget,
        requestedMigration: true
    )

    #expect(roots?.source == displayedSource)
    #expect(roots?.target == displayedTarget)
    #expect(try MigrationProgressView.migrationRoots(
        sourceURL: displayedSource,
        targetURL: displayedTarget,
        requestedMigration: false
    ) == nil)
}

@Test func migrationRootResolutionReportsMissingDisplayedRoots() {
    let target = URL(fileURLWithPath: "/tmp/cisum-storage-target", isDirectory: true)

    #expect(throws: MigrationError.self) {
        try MigrationProgressView.migrationRoots(
            sourceURL: nil,
            targetURL: target,
            requestedMigration: true
        )
    }

    #expect(throws: MigrationError.self) {
        try MigrationProgressView.migrationRoots(
            sourceURL: target,
            targetURL: nil,
            requestedMigration: true
        )
    }

    #expect(throws: MigrationError.self) {
        try MigrationProgressView.migrationRoots(
            sourceURL: target,
            targetURL: nil,
            requestedMigration: false
        )
    }
}

@Test func migrationPreviewSkipsDSStoreLikeMigrationManager() throws {
    let source = URL(fileURLWithPath: "/tmp/cisum-storage-source", isDirectory: true)

    let fileNames = try MigrationProgressView.migratableSourceFileNames(
        in: source,
        contentsOfDirectory: { _ in
            ["track.mp3", ".DS_Store", "album"]
        }
    )

    #expect(fileNames == ["album", "track.mp3"])
}

@Test func migrationMovesContentsButKeepsSourceRoot() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let target = root.appendingPathComponent("target", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: source.appendingPathComponent("track.mp3"))

    let manager = MigrationManager()
    try manager.migrate(
        from: source,
        to: target,
        progressCallback: nil,
        downloadProgressCallback: nil,
        verbose: false
    )

    #expect(FileManager.default.fileExists(atPath: source.path))
    #expect(FileManager.default.fileExists(atPath: target.appendingPathComponent("track.mp3").path))
    #expect(!FileManager.default.fileExists(atPath: source.appendingPathComponent("track.mp3").path))
}

@Test func migrationRejectsTargetInsideSourceRootBeforeMovingFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let target = source.appendingPathComponent("target", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: source.appendingPathComponent("track.mp3"))

    let manager = MigrationManager()

    #expect(MigrationManager.isTargetNestedInSource(sourceRoot: source, targetRoot: target))
    #expect(!MigrationManager.isTargetNestedInSource(sourceRoot: source, targetRoot: source))
    #expect(throws: MigrationError.self) {
        try manager.migrate(
            from: source,
            to: target,
            progressCallback: nil,
            downloadProgressCallback: nil,
            verbose: false
        )
    }

    #expect(FileManager.default.fileExists(atPath: source.appendingPathComponent("track.mp3").path))
    #expect(!FileManager.default.fileExists(atPath: target.path))
}

@Test func migrationTreatsRootSourceAsContainingTarget() {
    let source = URL(fileURLWithPath: "/", isDirectory: true)
    let target = URL(fileURLWithPath: "/tmp/cisum-storage-migration", isDirectory: true)

    #expect(MigrationManager.isTargetNestedInSource(sourceRoot: source, targetRoot: target))
    #expect(!MigrationManager.isTargetNestedInSource(sourceRoot: source, targetRoot: source))
}

@Test func migrationTreatsSymlinkedTargetRootAsSameSource() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let target = root.appendingPathComponent("source-link", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    let sourceFile = source.appendingPathComponent("track.mp3")
    try Data("audio".utf8).write(to: sourceFile)
    try FileManager.default.createSymbolicLink(at: target, withDestinationURL: source)

    var reportedProgress: Double?
    let manager = MigrationManager()
    try manager.migrate(
        from: source,
        to: target,
        progressCallback: { progress, _ in
            reportedProgress = progress
        },
        downloadProgressCallback: nil,
        verbose: false
    )

    #expect(reportedProgress == 1.0)
    #expect(FileManager.default.fileExists(atPath: sourceFile.path))
    #expect(!FileManager.default.fileExists(atPath: source.appendingPathComponent("track 2.mp3").path))
}

@Test func migrationRejectsTargetInsideSourceThroughSymlink() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let sourceLink = root.appendingPathComponent("source-link", isDirectory: true)
    let target = sourceLink.appendingPathComponent("target", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: source.appendingPathComponent("track.mp3"))
    try FileManager.default.createSymbolicLink(at: sourceLink, withDestinationURL: source)

    #expect(MigrationManager.isTargetNestedInSource(sourceRoot: source, targetRoot: target))

    let manager = MigrationManager()
    #expect(throws: MigrationError.self) {
        try manager.migrate(
            from: source,
            to: target,
            progressCallback: nil,
            downloadProgressCallback: nil,
            verbose: false
        )
    }

    #expect(FileManager.default.fileExists(atPath: source.appendingPathComponent("track.mp3").path))
    #expect(!FileManager.default.fileExists(atPath: target.path))
}

@Test func migrationReportsLocalAvailabilityBeforeMovingFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let target = root.appendingPathComponent("target", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: source.appendingPathComponent("track.mp3"))

    var statuses: [FileStatus.DownloadStatus] = []
    let manager = MigrationManager()
    try manager.migrate(
        from: source,
        to: target,
        progressCallback: nil,
        downloadProgressCallback: { _, status in
            statuses.append(status)
        },
        verbose: false
    )

    #expect(statuses.contains(.local))
    #expect(FileManager.default.fileExists(atPath: target.appendingPathComponent("track.mp3").path))
}

@Test func migrationReportsLocalAvailabilityForVisibleFolderDescendants() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let album = source.appendingPathComponent("album", isDirectory: true)
    let disc = album.appendingPathComponent("disc", isDirectory: true)
    let target = root.appendingPathComponent("target", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: disc, withIntermediateDirectories: true)
    try Data("one".utf8).write(to: album.appendingPathComponent("01.mp3"))
    try Data("two".utf8).write(to: disc.appendingPathComponent("02.mp3"))
    try Data("hidden".utf8).write(to: disc.appendingPathComponent(".hidden.mp3"))

    var statuses: [FileStatus.DownloadStatus] = []
    let manager = MigrationManager()
    try manager.migrate(
        from: source,
        to: target,
        progressCallback: nil,
        downloadProgressCallback: { _, status in
            statuses.append(status)
        },
        verbose: false
    )

    #expect(statuses.count == 4)
    #expect(statuses.filter { $0 == .local }.count == 2)
    #expect(FileManager.default.fileExists(atPath: target.appendingPathComponent("album/disc/.hidden.mp3").path))
}

@Test func migrationRenamesConflictingTargetFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let target = root.appendingPathComponent("target", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

    try Data("new".utf8).write(to: source.appendingPathComponent("track.mp3"))
    try Data("existing".utf8).write(to: target.appendingPathComponent("track.mp3"))

    let manager = MigrationManager()
    try manager.migrate(
        from: source,
        to: target,
        progressCallback: nil,
        downloadProgressCallback: nil,
        verbose: false
    )

    #expect(FileManager.default.fileExists(atPath: target.appendingPathComponent("track.mp3").path))
    #expect(FileManager.default.fileExists(atPath: target.appendingPathComponent("track 2.mp3").path))
    #expect(!FileManager.default.fileExists(atPath: source.appendingPathComponent("track.mp3").path))
}

@Test func migrationRenamesWhenTargetHasDanglingSymlink() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let target = root.appendingPathComponent("target", isDirectory: true)
    let danglingTarget = target.appendingPathComponent("track.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    try Data("new".utf8).write(to: source.appendingPathComponent("track.mp3"))
    try FileManager.default.createSymbolicLink(
        at: danglingTarget,
        withDestinationURL: target.appendingPathComponent("missing.mp3")
    )

    let manager = MigrationManager()
    try manager.migrate(
        from: source,
        to: target,
        progressCallback: nil,
        downloadProgressCallback: nil,
        verbose: false
    )

    #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: danglingTarget.path)) != nil)
    #expect(FileManager.default.fileExists(atPath: target.appendingPathComponent("track 2.mp3").path))
    #expect(!FileManager.default.fileExists(atPath: source.appendingPathComponent("track.mp3").path))
}

@Test func migrationCopiesSymlinkedFilesAsStandaloneFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let target = root.appendingPathComponent("target", isDirectory: true)
    let external = root.appendingPathComponent("external", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
    let realFile = external.appendingPathComponent("real.mp3")
    let linkedFile = source.appendingPathComponent("linked.mp3")
    try Data("audio".utf8).write(to: realFile)
    try FileManager.default.createSymbolicLink(at: linkedFile, withDestinationURL: realFile)

    let manager = MigrationManager()
    try manager.migrate(
        from: source,
        to: target,
        progressCallback: nil,
        downloadProgressCallback: nil,
        verbose: false
    )

    let migratedFile = target.appendingPathComponent("linked.mp3")
    let fileType = try FileManager.default.attributesOfItem(atPath: migratedFile.path)[.type] as? FileAttributeType

    #expect(fileType == .typeRegular)
    #expect((try Data(contentsOf: migratedFile)) == Data("audio".utf8))
    #expect(!FileManager.default.fileExists(atPath: linkedFile.path))
    #expect(FileManager.default.fileExists(atPath: realFile.path))
}

@Test func migrationReportsCompletionOnlyAfterMoveFinishes() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let target = root.appendingPathComponent("target", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

    let sourceFile = source.appendingPathComponent("track.mp3")
    let renamedTarget = target.appendingPathComponent("track 2.mp3")
    try Data("new".utf8).write(to: sourceFile)
    try Data("existing".utf8).write(to: target.appendingPathComponent("track.mp3"))

    var observations: [(progress: Double, sourceExists: Bool, renamedTargetExists: Bool)] = []
    let manager = MigrationManager()
    try manager.migrate(
        from: source,
        to: target,
        progressCallback: { progress, _ in
            observations.append((
                progress: progress,
                sourceExists: FileManager.default.fileExists(atPath: sourceFile.path),
                renamedTargetExists: FileManager.default.fileExists(atPath: renamedTarget.path)
            ))
        },
        downloadProgressCallback: nil,
        verbose: false
    )

    #expect(observations.count == 2)
    #expect(observations.first?.progress == 0)
    #expect(observations.first?.sourceExists == true)
    #expect(observations.first?.renamedTargetExists == false)
    #expect(observations.last?.progress == 1)
    #expect(observations.last?.sourceExists == false)
    #expect(observations.last?.renamedTargetExists == true)
}

@Test func emptyMigrationReportsCompleteProgress() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let target = root.appendingPathComponent("target", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)

    var reportedProgress: Double?
    let manager = MigrationManager()
    try manager.migrate(
        from: source,
        to: target,
        progressCallback: { progress, _ in
            reportedProgress = progress
        },
        downloadProgressCallback: nil,
        verbose: false
    )

    #expect(reportedProgress == 1.0)
    #expect(FileManager.default.fileExists(atPath: target.path))
}

@Test func migrationCancellationStopsBeforeMovingFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let target = root.appendingPathComponent("target", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: source.appendingPathComponent("track.mp3"))

    let manager = MigrationManager()
    manager.cancelMigration()

    #expect(throws: MigrationError.self) {
        try manager.migrate(
            from: source,
            to: target,
            progressCallback: nil,
            downloadProgressCallback: nil,
            verbose: false
        )
    }

    #expect(FileManager.default.fileExists(atPath: source.appendingPathComponent("track.mp3").path))
    #expect(!FileManager.default.fileExists(atPath: target.appendingPathComponent("track.mp3").path))
    #expect(!FileManager.default.fileExists(atPath: target.path))
}

@Test func migrationCancellationKeepsPreexistingEmptyTargetDirectory() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let target = root.appendingPathComponent("target", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: source.appendingPathComponent("track.mp3"))

    let manager = MigrationManager()
    manager.cancelMigration()

    #expect(throws: MigrationError.self) {
        try manager.migrate(
            from: source,
            to: target,
            progressCallback: nil,
            downloadProgressCallback: nil,
            verbose: false
        )
    }

    #expect(FileManager.default.fileExists(atPath: source.appendingPathComponent("track.mp3").path))
    #expect(FileManager.default.fileExists(atPath: target.path))
    #expect(!FileManager.default.fileExists(atPath: target.appendingPathComponent("track.mp3").path))
}

@Test func migrationCancellationRequestedFromProgressStopsBeforeMovingCurrentFile() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let target = root.appendingPathComponent("target", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: source.appendingPathComponent("track.mp3"))

    let manager = MigrationManager()

    #expect(throws: MigrationError.self) {
        try manager.migrate(
            from: source,
            to: target,
            progressCallback: { _, _ in
                manager.cancelMigration()
            },
            downloadProgressCallback: nil,
            verbose: false
        )
    }

    #expect(FileManager.default.fileExists(atPath: source.appendingPathComponent("track.mp3").path))
    #expect(!FileManager.default.fileExists(atPath: target.appendingPathComponent("track.mp3").path))
}

// MARK: - Storage Observer + ViewModel 生命周期（迁移 Phase 1）

@MainActor
@Test func storageObserverPerformsInitialSync() {
    let service = StorageProvider()
    let viewModel = StorageSettingsViewModel(
        capability: StorageSettingsCapabilityAdapter(storage: service)
    )
    let observer = StorageProvidingObserver(provider: service, viewModel: viewModel)
    defer { observer.cancel() }

    // 监听安装前已经存在的状态不能丢失。
    #expect(viewModel.location == service.currentStorageLocation.map { StoragePluginLocation($0) })
    #expect(viewModel.isICloudAvailable == (service.storageRoot(for: .icloud) != nil))
    #expect(viewModel.isLocalStorageAvailable == (service.storageRoot(for: .local) != nil))
}

@MainActor
@Test func storageObserverForwardsLocationChangeToViewModel() {
    let service = StorageProvider()
    let viewModel = StorageSettingsViewModel(
        capability: StorageSettingsCapabilityAdapter(storage: service)
    )
    let observer = StorageProvidingObserver(provider: service, viewModel: viewModel)
    defer { observer.cancel() }

    service.setStorageLocation(.local)
    #expect(viewModel.location == .local)

    service.resetStorageLocation()
    #expect(viewModel.location == nil)
}

@MainActor
@Test func storageObserverCancelStopsViewModelUpdates() {
    let service = StorageProvider()
    let viewModel = StorageSettingsViewModel(
        capability: StorageSettingsCapabilityAdapter(storage: service)
    )
    let observer = StorageProvidingObserver(provider: service, viewModel: viewModel)

    observer.cancel()
    service.setStorageLocation(.local)
    #expect(viewModel.location == nil)
}


// MARK: - Plugin Data Directory（迁移：插件状态存储到自己的磁盘目录）

@MainActor
@Test func pluginDataDirectoryResolvesUnderDatabaseRootAndCreates() {
    let service = StorageProvider()
    let dir = service.pluginDataDirectory(for: "PluginManager")

    // 路径为 <databaseRoot>/PluginManager/
    #expect(dir.path.hasPrefix(service.databaseRoot.path))
    #expect(dir.lastPathComponent == "PluginManager")

    // 目录已按需创建
    var isDirectory: ObjCBool = false
    #expect(FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDirectory))
    #expect(isDirectory.boolValue)
}

@MainActor
@Test func pluginDataDirectoryKeepsPerPluginSubdirectories() {
    let service = StorageProvider()
    let first = service.pluginDataDirectory(for: "PluginAlpha")
    let second = service.pluginDataDirectory(for: "PluginBeta")

    #expect(first.lastPathComponent == "PluginAlpha")
    #expect(second.lastPathComponent == "PluginBeta")
    #expect(first.path != second.path)
}

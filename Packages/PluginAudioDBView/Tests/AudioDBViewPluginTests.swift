import Testing
@testable import PluginAudioDBView
import Foundation
import UniformTypeIdentifiers

@Test func audioDBInfoExportsMetadata() {
    #expect(AudioDBPluginInfo.titleKey == "Audio Repository")
}

@Test func audioDBSortModeRestoresTrimmedNotificationValues() {
    #expect(AudioDBViewModel.sortMode(from: "random") == .random)
    #expect(AudioDBViewModel.sortMode(from: " order\n") == .order)
    #expect(AudioDBViewModel.sortMode(from: "missing") == .none)
}

@Test func audioImportCleansCopiedFilesWhenBatchFails() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let destinationRoot = root.appendingPathComponent("destination", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
    let validSource = sourceRoot.appendingPathComponent("valid.mp3")
    let missingSource = sourceRoot.appendingPathComponent("missing.mp3")
    try Data("audio".utf8).write(to: validSource)

    await #expect(throws: Error.self) {
        try await AudioDBView.copyFilesInBackground([validSource, missingSource], to: destinationRoot)
    }

    #expect(FileManager.default.fileExists(atPath: destinationRoot.appendingPathComponent("valid.mp3").path) == false)
}

@Test func audioImportCleansCopiedFilesWhenRepositoryIsUnavailable() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let copiedFile = root.appendingPathComponent("orphaned.mp3")
    try Data("audio".utf8).write(to: copiedFile)

    AudioDBView.cleanUpCopiedFiles([copiedFile])

    #expect(FileManager.default.fileExists(atPath: copiedFile.path) == false)
}

@Test func audioImportCopiesSymlinkedFilesAsStandaloneFiles() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let destinationRoot = root.appendingPathComponent("destination", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
    let realSource = sourceRoot.appendingPathComponent("real.mp3")
    let linkedSource = sourceRoot.appendingPathComponent("linked.mp3")
    try Data("audio".utf8).write(to: realSource)
    try FileManager.default.createSymbolicLink(at: linkedSource, withDestinationURL: realSource)

    let copiedFiles = try await AudioDBView.copyFilesInBackground([linkedSource], to: destinationRoot)
    let copiedFile = try #require(copiedFiles.first)
    let fileType = try FileManager.default.attributesOfItem(atPath: copiedFile.path)[.type] as? FileAttributeType

    #expect(copiedFile.lastPathComponent == "linked.mp3")
    #expect(fileType == .typeRegular)
    #expect((try Data(contentsOf: copiedFile)) == Data("audio".utf8))
}

@Test func audioImportAvoidsDanglingSymlinkDestinationNames() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let destinationRoot = root.appendingPathComponent("destination", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: destinationRoot, withIntermediateDirectories: true)
    let source = sourceRoot.appendingPathComponent("track.mp3")
    let danglingDestination = destinationRoot.appendingPathComponent("track.mp3")
    try Data("audio".utf8).write(to: source)
    try FileManager.default.createSymbolicLink(
        at: danglingDestination,
        withDestinationURL: destinationRoot.appendingPathComponent("missing.mp3")
    )

    let copiedFiles = try await AudioDBView.copyFilesInBackground([source], to: destinationRoot)
    let copiedFile = try #require(copiedFiles.first)

    #expect(copiedFile.lastPathComponent == "track 2.mp3")
    #expect((try Data(contentsOf: copiedFile)) == Data("audio".utf8))
    #expect((try? danglingDestination.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true)
}

@Test func audioListRejectsStaleDeleteOffsets() {
    let root = URL(fileURLWithPath: "/tmp/cisum-audio-list-tests", isDirectory: true)
    let urls = [
        root.appendingPathComponent("one.mp3"),
        root.appendingPathComponent("two.mp3"),
    ]

    #expect(AudioListViewModel.urlsToDelete(from: IndexSet(integer: 1), in: urls) == [urls[1]])
    #expect(AudioListViewModel.urlsToDelete(from: IndexSet(integer: 2), in: urls) == nil)
}

@Test func audioListHeaderKeepsAddButtonWhileRepositoryHasContent() {
    // 非空仓库在表头最右侧常驻「添加」按钮：桌面端同样有可点击的导入入口，
    // 不再只能靠把文件拖进窗口。
    #expect(AudioListHeaderPolicy.shouldShowAddButton(hasContent: true))
    // 空仓库由空状态视图自己提供「添加」按钮，表头不再重复出现。
    #expect(!AudioListHeaderPolicy.shouldShowAddButton(hasContent: false))
}

@Test func audioListHeaderKeepsOpenRepositoryButtonWhileRepositoryHasContent() {
    // 非空仓库在表头最右侧常驻「打开仓库目录」按钮：用户可直接跳到访达里的仓库目录。
    #expect(AudioListHeaderPolicy.shouldShowOpenRepositoryButton(hasContent: true))
    // 空仓库由空状态视图自己提供目录入口，表头不再重复出现。
    #expect(!AudioListHeaderPolicy.shouldShowOpenRepositoryButton(hasContent: false))
}

@Test func audioListLoadsMoreFromCurrentLoadedCount() {
    #expect(AudioListLoadPolicy.nextLoadOffset(loadedCount: 90, currentPage: 0, pageSize: 50) == 90)
    #expect(AudioListLoadPolicy.nextLoadOffset(loadedCount: 100, currentPage: 0, pageSize: 50) == 100)
    #expect(AudioListLoadPolicy.nextLoadOffset(loadedCount: 90, currentPage: 2, pageSize: 50) == 100)
    #expect(AudioListLoadPolicy.nextLoadOffset(loadedCount: 120, currentPage: 2, pageSize: 50) == 120)
    #expect(AudioListLoadPolicy.pageAfterLoading(currentPage: 2, fetchedCount: 50) == 3)
    #expect(AudioListLoadPolicy.pageAfterLoading(currentPage: 2, fetchedCount: 0) == 2)
}

@Test func audioListLoadMoreDoesNotSkipAfterDisplayedRowsShrink() {
    #expect(AudioListLoadPolicy.nextLoadOffset(loadedCount: 40, currentPage: 1, pageSize: 50) == 50)
    #expect(AudioListLoadPolicy.nextLoadOffset(loadedCount: 90, currentPage: 3, pageSize: 50) == 150)
}

@Test func audioListDeletionRebasesPaginationToRemainingDisplayedRows() {
    #expect(AudioListLoadPolicy.currentPageAfterDeletingDisplayedItems(
        remainingDisplayedCount: 20,
        pageSize: 50
    ) == 0)
    #expect(AudioListLoadPolicy.nextLoadOffset(
        loadedCount: 20,
        currentPage: AudioListLoadPolicy.currentPageAfterDeletingDisplayedItems(
            remainingDisplayedCount: 20,
            pageSize: 50
        ),
        pageSize: 50
    ) == 20)
    #expect(AudioListLoadPolicy.currentPageAfterDeletingDisplayedItems(
        remainingDisplayedCount: 80,
        pageSize: 50
    ) == 1)
    #expect(AudioListLoadPolicy.nextLoadOffset(
        loadedCount: 80,
        currentPage: AudioListLoadPolicy.currentPageAfterDeletingDisplayedItems(
            remainingDisplayedCount: 80,
            pageSize: 50
        ),
        pageSize: 50
    ) == 80)
    #expect(AudioListLoadPolicy.currentPageAfterDeletingDisplayedItems(
        remainingDisplayedCount: 10,
        pageSize: 0
    ) == 0)
}

@Test func audioListLoadMoreOffsetAdvancesByFetchedPagesAfterDeduplication() {
    #expect(AudioListLoadPolicy.nextLoadOffset(loadedCount: 50, currentPage: 2, pageSize: 50) == 100)
    #expect(AudioListLoadPolicy.nextLoadOffset(loadedCount: 115, currentPage: 2, pageSize: 50) == 115)
}

@Test func audioListLoadMoreTriggerUsesVisibleIndex() {
    #expect(!AudioListLoadPolicy.shouldLoadMore(
        currentIndex: 89,
        loadedCount: 100,
        hasMore: true,
        isLoadingMore: false
    ))
    #expect(AudioListLoadPolicy.shouldLoadMore(
        currentIndex: 90,
        loadedCount: 100,
        hasMore: true,
        isLoadingMore: false
    ))
    #expect(AudioListLoadPolicy.shouldLoadMore(
        currentIndex: 40,
        loadedCount: 50,
        hasMore: true,
        isLoadingMore: false
    ))
    #expect(!AudioListLoadPolicy.shouldLoadMore(
        currentIndex: 99,
        loadedCount: 100,
        hasMore: false,
        isLoadingMore: false
    ))
    #expect(!AudioListLoadPolicy.shouldLoadMore(
        currentIndex: 99,
        loadedCount: 100,
        hasMore: true,
        isLoadingMore: true
    ))
    #expect(!AudioListLoadPolicy.shouldLoadMore(
        currentIndex: -1,
        loadedCount: 100,
        hasMore: true,
        isLoadingMore: false
    ))
}

@Test func audioListOnlyAppliesCurrentLoadGeneration() {
    #expect(AudioListLoadPolicy.shouldApplyResult(currentGeneration: 2, resultGeneration: 2))
    #expect(!AudioListLoadPolicy.shouldApplyResult(currentGeneration: 3, resultGeneration: 2))
}

@Test func audioListLoadMoreDeduplicatesSymlinkedRows() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realFile = root.appendingPathComponent("real.mp3")
    let linkedFile = root.appendingPathComponent("linked.mp3")
    let otherFile = root.appendingPathComponent("other.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: realFile)
    try Data("other".utf8).write(to: otherFile)
    try FileManager.default.createSymbolicLink(at: linkedFile, withDestinationURL: realFile)

    #expect(AudioListLoadPolicy.uniqueAdditionalURLs(
        existingURLs: [linkedFile],
        newURLs: [realFile, otherFile, otherFile]
    ) == [otherFile])
}

@Test func audioListLoadMoreTracksFetchedPageSizeAfterDeduplication() {
    #expect(AudioListLoadPolicy.hasMoreAfterLoading(fetchedCount: 50, pageSize: 50))
    #expect(!AudioListLoadPolicy.hasMoreAfterLoading(fetchedCount: 49, pageSize: 50))
}

@Test func staleAudioListResultsKeepCurrentLoadingState() {
    #expect(AudioListLoadPolicy.shouldKeepLoadingStateWhenDiscardingStaleResult(
        currentGeneration: 3,
        resultGeneration: 2
    ))
    #expect(!AudioListLoadPolicy.shouldKeepLoadingStateWhenDiscardingStaleResult(
        currentGeneration: 2,
        resultGeneration: 2
    ))
}

@Test func audioListCurrentPageRefreshClearsStalePaginationLoading() {
    let populatedState = AudioListLoadPolicy.loadingStateWhenStartingCurrentPageRefresh(displayedCount: 20)
    #expect(populatedState.isLoading == false)
    #expect(populatedState.isLoadingMore == false)

    let emptyState = AudioListLoadPolicy.loadingStateWhenStartingCurrentPageRefresh(displayedCount: 0)
    #expect(emptyState.isLoading == true)
    #expect(emptyState.isLoadingMore == false)
}

@Test func audioListDeletionInvalidatesPendingLoads() {
    let generation = AudioListLoadPolicy.generationAfterDeletingDisplayedItems(2)

    #expect(generation == 3)
    #expect(!AudioListLoadPolicy.shouldApplyResult(
        currentGeneration: generation,
        resultGeneration: 2
    ))
}

@Test func audioListDeletionMatchesSymlinkedRows() throws {
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

    #expect(AudioListDeletionPolicy.shouldRemove(realFile, deletedURLs: [linkedFile]))
    #expect(AudioListDeletionPolicy.shouldRemove(linkedFile, deletedURLs: [realFile]))
    #expect(!AudioListDeletionPolicy.shouldRemove(
        root.appendingPathComponent("other.mp3"),
        deletedURLs: [linkedFile]
    ))
}

@Test func audioListDeletionMatchesDanglingSymlinkRows() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingFile = root.appendingPathComponent("missing.mp3")
    let linkedFile = root.appendingPathComponent("linked.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedFile, withDestinationURL: missingFile)

    #expect(AudioListDeletionPolicy.shouldRemove(linkedFile, deletedURLs: [linkedFile]))
    #expect(!AudioListDeletionPolicy.shouldRemove(
        root.appendingPathComponent("other.mp3"),
        deletedURLs: [linkedFile]
    ))
}

@Test func audioListDeletionCountsOnlyDisplayedRemovedRows() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realFile = root.appendingPathComponent("real.mp3")
    let linkedFile = root.appendingPathComponent("linked.mp3")
    let otherFile = root.appendingPathComponent("other.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: realFile)
    try FileManager.default.createSymbolicLink(at: linkedFile, withDestinationURL: realFile)

    #expect(AudioListDeletionPolicy.removedDisplayedCount(
        from: [realFile, otherFile],
        deletedURLs: [linkedFile, realFile]
    ) == 1)
}

@Test func audioListDeletionUpdatesTotalForUnloadedDeletedRows() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realFile = root.appendingPathComponent("real.mp3")
    let linkedFile = root.appendingPathComponent("linked.mp3")
    let unloadedFile = root.appendingPathComponent("unloaded.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: realFile)
    try Data("audio".utf8).write(to: unloadedFile)
    try FileManager.default.createSymbolicLink(at: linkedFile, withDestinationURL: realFile)

    #expect(AudioListDeletionPolicy.removedDisplayedCount(
        from: [realFile],
        deletedURLs: [unloadedFile]
    ) == 0)
    #expect(AudioListDeletionPolicy.totalCountAfterDeletion(
        currentTotal: 10,
        deletedURLs: [unloadedFile]
    ) == 9)
    #expect(AudioListDeletionPolicy.totalCountAfterDeletion(
        currentTotal: 10,
        deletedURLs: [realFile, linkedFile, unloadedFile]
    ) == 8)
    #expect(AudioListDeletionPolicy.totalCountAfterDeletion(
        currentTotal: 1,
        deletedURLs: [realFile, unloadedFile]
    ) == 0)
}

@Test func audioListDeletionCountsDistinctDanglingSymlinkRows() throws {
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

    #expect(AudioListDeletionPolicy.totalCountAfterDeletion(
        currentTotal: 10,
        deletedURLs: [firstLink, secondLink]
    ) == 8)
}

@Test func audioListOnlyAppliesCurrentSelectionPlayback() {
    let first = URL(fileURLWithPath: "/tmp/cisum-audio-selection/first.mp3")
    let second = URL(fileURLWithPath: "/tmp/cisum-audio-selection/second.mp3")

    #expect(AudioListSelectionPolicy.shouldApplySelection(
        currentGeneration: 2,
        requestGeneration: 2,
        requestedURL: first,
        selection: first,
        displayedURLs: [first, second]
    ))
    #expect(!AudioListSelectionPolicy.shouldApplySelection(
        currentGeneration: 3,
        requestGeneration: 2,
        requestedURL: first,
        selection: first,
        displayedURLs: [first, second]
    ))
    #expect(!AudioListSelectionPolicy.shouldApplySelection(
        currentGeneration: 2,
        requestGeneration: 2,
        requestedURL: first,
        selection: second,
        displayedURLs: [first, second]
    ))
    #expect(!AudioListSelectionPolicy.shouldApplySelection(
        currentGeneration: 2,
        requestGeneration: 2,
        requestedURL: first,
        selection: first,
        displayedURLs: [second]
    ))
}

@Test func audioListSelectionTreatsSymlinkedAudioAsSameFile() throws {
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

    #expect(AudioListSelectionPolicy.shouldApplySelection(
        currentGeneration: 2,
        requestGeneration: 2,
        requestedURL: linkedFile,
        selection: realFile,
        displayedURLs: [realFile]
    ))
    #expect(AudioListSelectionPolicy.representsSameAudio(realFile, linkedFile))
    #expect(AudioListSelectionPolicy.representsSameAudio(nil, nil))
    #expect(!AudioListSelectionPolicy.representsSameAudio(realFile, nil))
    #expect(!AudioListSelectionPolicy.representsSameAudio(
        realFile,
        root.appendingPathComponent("other.mp3")
    ))
}

@Test func audioListSelectionKeepsDistinctDanglingSymlinkAudioSeparate() throws {
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

    #expect(!AudioListSelectionPolicy.representsSameAudio(firstLink, secondLink))
    #expect(!AudioListSelectionPolicy.shouldApplySelection(
        currentGeneration: 2,
        requestGeneration: 2,
        requestedURL: firstLink,
        selection: secondLink,
        displayedURLs: [firstLink, secondLink]
    ))
}

@Test func audioDeleteOnlyResetsPlaybackForStillCurrentDeletedAudio() {
    let root = URL(fileURLWithPath: "/tmp/cisum-audio-delete-tests", isDirectory: true)
    let deleted = root.appendingPathComponent("deleted.mp3")
    let unstandardizedDeleted = root
        .appendingPathComponent("nested", isDirectory: true)
        .appendingPathComponent("..", isDirectory: true)
        .appendingPathComponent("deleted.mp3")
    let switched = root.appendingPathComponent("switched.mp3")

    #expect(AudioDeletePlaybackPolicy.deletedURLsContainCurrentAudio(
        currentURL: deleted,
        deletedURLs: [deleted]
    ))
    #expect(AudioDeletePlaybackPolicy.deletedURLsContainCurrentAudio(
        currentURL: deleted,
        deletedURLs: [unstandardizedDeleted]
    ))
    #expect(!AudioDeletePlaybackPolicy.deletedURLsContainCurrentAudio(
        currentURL: switched,
        deletedURLs: [deleted]
    ))
    #expect(!AudioDeletePlaybackPolicy.deletedURLsContainCurrentAudio(
        currentURL: nil,
        deletedURLs: [deleted]
    ))
    #expect(!AudioDeletePlaybackPolicy.shouldResetDirectlyAfterDelete(
        currentURL: deleted,
        deletedURLs: [deleted],
        isPlaybackControllerHandlingDeletion: true
    ))
    #expect(AudioDeletePlaybackPolicy.shouldResetDirectlyAfterDelete(
        currentURL: deleted,
        deletedURLs: [deleted],
        isPlaybackControllerHandlingDeletion: false
    ))
}

@Test func audioDeleteResetsPlaybackForSymlinkedCurrentAudio() throws {
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

    #expect(AudioDeletePlaybackPolicy.deletedURLsContainCurrentAudio(
        currentURL: realFile,
        deletedURLs: [linkedFile]
    ))
}

@Test func audioDeleteResetsPlaybackForDanglingSymlinkCurrentAudio() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingFile = root.appendingPathComponent("missing.mp3")
    let linkedFile = root.appendingPathComponent("linked.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkedFile, withDestinationURL: missingFile)

    #expect(AudioDeletePlaybackPolicy.deletedURLsContainCurrentAudio(
        currentURL: linkedFile,
        deletedURLs: [linkedFile]
    ))
}

@Test func audioDeleteDoesNotResetPlaybackForDistinctDanglingSymlinkAudio() throws {
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

    #expect(!AudioDeletePlaybackPolicy.deletedURLsContainCurrentAudio(
        currentURL: secondLink,
        deletedURLs: [firstLink]
    ))
    #expect(!AudioDeletePlaybackPolicy.shouldResetDirectlyAfterDelete(
        currentURL: secondLink,
        deletedURLs: [firstLink],
        isPlaybackControllerHandlingDeletion: false
    ))
}

@Test func audioItemOnlyAppliesCurrentFileSize() {
    let root = URL(fileURLWithPath: "/tmp/cisum-audio-item-tests", isDirectory: true)
    let first = root.appendingPathComponent("first.mp3")
    let second = root.appendingPathComponent("second.mp3")

    #expect(AudioItemFileSizeLoadPolicy.shouldApplySize(currentURL: first, requestedURL: first))
    #expect(!AudioItemFileSizeLoadPolicy.shouldApplySize(currentURL: second, requestedURL: first))
}

@Test func audioItemAppliesFileSizeForSymlinkedCurrentFile() throws {
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

    #expect(AudioItemFileSizeLoadPolicy.shouldApplySize(
        currentURL: realFile,
        requestedURL: linkedFile
    ))
}

@Test func audioItemDoesNotApplyFileSizeAcrossDistinctDanglingSymlinks() throws {
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

    #expect(!AudioItemFileSizeLoadPolicy.shouldApplySize(
        currentURL: secondLink,
        requestedURL: firstLink
    ))
}

@Test func audioItemFileSizeReadPolicyReadsFoundationAttributes() {
    #expect(AudioItemFileSizeReadPolicy.fileSize(from: [.size: NSNumber(value: 1234)]) == 1234)
    #expect(AudioItemFileSizeReadPolicy.fileSize(from: [.size: Int64(5678)]) == 5678)
    #expect(AudioItemFileSizeReadPolicy.fileSize(from: [.size: Int(90)]) == 90)
    #expect(AudioItemFileSizeReadPolicy.fileSize(from: [.size: UInt64(42)]) == 42)
}

@Test func audioItemFileSizeReadPolicyNormalizesInvalidSizes() {
    #expect(AudioItemFileSizeReadPolicy.fileSize(from: [.size: NSNumber(value: -1234)]) == 0)
    #expect(AudioItemFileSizeReadPolicy.fileSize(from: [.size: Int64(-5678)]) == 0)
    #expect(AudioItemFileSizeReadPolicy.fileSize(from: [.size: UInt64.max]) == Int64.max)
    #expect(AudioItemFileSizeReadPolicy.fileSize(from: [:]) == nil)
}

@Test func audioItemFileSizeDisplayPolicySeparatesLoadingAndUnavailable() {
    #expect(AudioItemFileSizeDisplayPolicy.state(fileSize: nil, isUnavailable: false) == .loading)
    #expect(AudioItemFileSizeDisplayPolicy.state(fileSize: nil, isUnavailable: true) == .unavailable)
    #expect(AudioItemFileSizeDisplayPolicy.state(fileSize: 2048, isUnavailable: true) == .size(2048))
}

@MainActor
@Test func audioItemFileSizeCacheStoresHitsAndMisses() {
    let root = URL(fileURLWithPath: "/tmp/cisum-audio-item-cache-tests", isDirectory: true)
    let file = root.appendingPathComponent("track.mp3")
    let missing = root.appendingPathComponent("missing.mp3")

    AudioItemFileSizeCache.removeAll()

    #expect(AudioItemFileSizeCache.cachedSize(for: file) == nil)

    AudioItemFileSizeCache.store(12, for: file)
    #expect(AudioItemFileSizeCache.cachedSize(for: file) == Optional(Optional(Int64(12))))

    // 读取失败**不入缓存**：iCloud 占位文件在下载完成前读不到大小，若把失败缓存下来，
    // 条目在下载完成后仍会永远显示「不可用」，且没有任何信号能触发重读。
    AudioItemFileSizeCache.store(nil, for: missing)
    #expect(AudioItemFileSizeCache.cachedSize(for: missing) == nil)

    AudioItemFileSizeCache.remove([file])
    #expect(AudioItemFileSizeCache.cachedSize(for: file) == nil)

    AudioItemFileSizeCache.removeAll()
    #expect(AudioItemFileSizeCache.cachedSize(for: file) == nil)
}

/// 回归：占位文件（下载前读不到大小）在下载完成后必须能读到真实大小。
///
/// 若失败结果被缓存，条目标记为「不可用」后就没有任何信号能触发重读，用户会一直
/// 看到「不可用」。
@MainActor
@Test func audioItemFileSizeCacheAllowsRetryAfterDownloadCompletes() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("cisum-size-retry-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let file = root.appendingPathComponent("dataless.mp3")
    AudioItemFileSizeCache.removeAll()

    // 下载前：文件尚未落地，读取失败。
    #expect(AudioItemFileSizeReadPolicy.currentFileSize(for: file) == nil)
    AudioItemFileSizeCache.store(AudioItemFileSizeReadPolicy.currentFileSize(for: file), for: file)
    #expect(AudioItemFileSizeCache.cachedSize(for: file) == nil)

    // 下载完成：真实内容落地。
    try Data(repeating: 0x41, count: 4096).write(to: file)
    let sizeAfterDownload = AudioItemFileSizeReadPolicy.currentFileSize(for: file)
    #expect(sizeAfterDownload == 4096)

    // 重读必须成功——这正是「失败不入缓存」的意义。
    AudioItemFileSizeCache.store(sizeAfterDownload, for: file)
    #expect(AudioItemFileSizeCache.cachedSize(for: file) == Optional(Optional(Int64(4096))))

    AudioItemFileSizeCache.removeAll()
}

@MainActor
@Test func audioItemFileSizeCacheMatchesSymlinkedFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realFile = root.appendingPathComponent("real.mp3")
    let linkedFile = root.appendingPathComponent("linked.mp3")
    defer {
        AudioItemFileSizeCache.removeAll()
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: realFile)
    try FileManager.default.createSymbolicLink(at: linkedFile, withDestinationURL: realFile)

    AudioItemFileSizeCache.removeAll()
    AudioItemFileSizeCache.store(5, for: realFile)

    #expect(AudioItemFileSizeCache.cachedSize(for: linkedFile) == Optional(Optional(Int64(5))))
}

@Test func audioItemExportUsesHumanNumberingForDuplicateDownloads() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let existing = root.appendingPathComponent("track.mp3")
    try Data("audio".utf8).write(to: existing)

    let source = URL(fileURLWithPath: "/tmp/source/track.mp3")
    let destination = AudioItemView.uniqueDestination(for: source, in: root)

    #expect(destination.lastPathComponent == "track 2.mp3")
}

@Test func audioItemExportAvoidsDanglingSymlinkDestinationNames() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let danglingDestination = root.appendingPathComponent("track.mp3")
    try FileManager.default.createSymbolicLink(
        at: danglingDestination,
        withDestinationURL: root.appendingPathComponent("missing.mp3")
    )

    let source = URL(fileURLWithPath: "/tmp/source/track.mp3")
    let destination = AudioItemView.uniqueDestination(for: source, in: root)

    #expect(destination.lastPathComponent == "track 2.mp3")
}

@Test func audioItemRevealInFinderRequiresExistingPathEntry() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let existingFile = root.appendingPathComponent("track.mp3")
    let danglingLink = root.appendingPathComponent("dangling.mp3")
    let missingFile = root.appendingPathComponent("missing.mp3")

    try Data("audio".utf8).write(to: existingFile)
    try FileManager.default.createSymbolicLink(
        at: danglingLink,
        withDestinationURL: root.appendingPathComponent("deleted-target.mp3")
    )

    #expect(AudioItemFileActionPolicy.canRevealInFinder(existingFile))
    #expect(AudioItemFileActionPolicy.canRevealInFinder(danglingLink))
    #expect(!AudioItemFileActionPolicy.canRevealInFinder(missingFile))
}

@Test func audioItemExportCopiesSymlinkedFilesAsStandaloneFiles() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let downloadsRoot = root.appendingPathComponent("downloads", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: downloadsRoot, withIntermediateDirectories: true)
    let realSource = sourceRoot.appendingPathComponent("real.mp3")
    let linkedSource = sourceRoot.appendingPathComponent("linked.mp3")
    try Data("audio".utf8).write(to: realSource)
    try FileManager.default.createSymbolicLink(at: linkedSource, withDestinationURL: realSource)

    let copiedFile = try await AudioItemView.copyToDownloads(linkedSource, downloadsURL: downloadsRoot)
    let fileType = try FileManager.default.attributesOfItem(atPath: copiedFile.path)[.type] as? FileAttributeType

    #expect(copiedFile.lastPathComponent == "linked.mp3")
    #expect(fileType == .typeRegular)
    #expect((try Data(contentsOf: copiedFile)) == Data("audio".utf8))
}

@Test func audioItemExportCreatesMissingDownloadsDirectory() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let downloadsRoot = root.appendingPathComponent("missing-downloads", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
    let source = sourceRoot.appendingPathComponent("track.mp3")
    try Data("audio".utf8).write(to: source)

    let copiedFile = try await AudioItemView.copyToDownloads(source, downloadsURL: downloadsRoot)

    #expect(FileManager.default.fileExists(atPath: downloadsRoot.path))
    #expect(copiedFile.deletingLastPathComponent() == downloadsRoot)
    #expect((try Data(contentsOf: copiedFile)) == Data("audio".utf8))
}

@Test func audioImportFiltersUnsupportedDroppedItems() {
    let root = URL(fileURLWithPath: "/tmp/cisum-audio-import-filter-tests", isDirectory: true)
    let supported = root.appendingPathComponent("track.MP3")
    let unsupported = root.appendingPathComponent("notes.txt")
    let folder = root.appendingPathComponent("folder", isDirectory: true)

    #expect(AudioDBView.supportedImportURLs(
        from: [supported, unsupported, folder],
        supportedExtensions: ["mp3", "wav"]
    ) == [supported])
}

@Test func audioImportDeduplicatesSymlinkedImportSources() throws {
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

    #expect(AudioDBView.representsSameImportSource(realFile, linkedFile))
    #expect(AudioDBView.canonicalImportSourceIdentity(for: realFile) == AudioDBView.canonicalImportSourceIdentity(for: linkedFile))
    #expect(AudioDBView.supportedImportURLs(
        from: [linkedFile, realFile],
        supportedExtensions: ["mp3"]
    ) == [linkedFile])
}

@Test func audioImportKeepsDistinctDanglingSymlinkImportSources() throws {
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

    #expect(!AudioDBView.representsSameImportSource(firstLink, secondLink))
    #expect(AudioDBView.supportedImportURLs(
        from: [firstLink, secondLink],
        supportedExtensions: ["mp3"]
    ) == [firstLink, secondLink])
}

@Test func audioDropReadsFileURLDataProvider() async throws {
    let expected = URL(fileURLWithPath: "/tmp/cisum-audio-drop-provider-tests/track.mp3")
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
        completion(expected.dataRepresentation, nil)
        return nil
    }

    let url = try await AudioDBView.droppedFileURL(from: provider)

    #expect(url == expected)
}

@Test func audioDropFallsBackToURLObjectAfterInvalidFileURLData() async throws {
    let expected = URL(fileURLWithPath: "/tmp/cisum-audio-drop-provider-tests/track.mp3")
    let provider = NSItemProvider(object: expected as NSURL)
    provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
        completion(Data("not a file url".utf8), nil)
        return nil
    }

    let url = try await AudioDBView.droppedFileURL(from: provider)

    #expect(url == expected)
}

@Test func audioDropFallsBackToURLObjectAfterFileURLDataError() async throws {
    let expected = URL(fileURLWithPath: "/tmp/cisum-audio-drop-provider-tests/track.mp3")
    let provider = NSItemProvider(object: expected as NSURL)
    let error = NSError(domain: "AudioDrop", code: 1)
    provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
        completion(nil, error)
        return nil
    }

    let url = try await AudioDBView.droppedFileURL(from: provider)

    #expect(url == expected)
}

@Test func audioDropSkipsEmptyImportAfterProviderFailure() {
    let error = NSError(domain: "AudioDrop", code: 1)
    let url = URL(fileURLWithPath: "/tmp/cisum-audio-drop-provider-tests/track.mp3")

    #expect(AudioDBView.shouldImportDroppedURLs([], after: [error]) == false)
    #expect(AudioDBView.shouldImportDroppedURLs([url], after: [error]) == true)
    #expect(AudioDBView.shouldImportDroppedURLs([], after: []) == false)
    #expect(AudioDBView.shouldReportDroppedURLLoadFailure([], errors: [error]))
    #expect(!AudioDBView.shouldReportDroppedURLLoadFailure([url], errors: [error]))
    #expect(!AudioDBView.shouldReportDroppedURLLoadFailure([], errors: []))
    #expect(AudioDBView.shouldReportPartialDroppedURLLoadFailure([url], errors: [error]))
    #expect(!AudioDBView.shouldReportPartialDroppedURLLoadFailure([], errors: [error]))
    #expect(!AudioDBView.shouldReportPartialDroppedURLLoadFailure([url], errors: []))
}

@Test func audioImportDoesNotStartWhileAlreadyImporting() {
    #expect(AudioDBView.shouldStartImport(isImporting: false))
    #expect(!AudioDBView.shouldStartImport(isImporting: true))
}

@Test func audioImportAllowsReadableLocalFilesWithoutSecurityScope() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let readableFile = root.appendingPathComponent("track.mp3")
    let missingFile = root.appendingPathComponent("missing.mp3")
    try Data("audio".utf8).write(to: readableFile)

    #expect(AudioDBView.hasImportSourceAccess(readableFile, securityScopeGranted: false))
    #expect(AudioDBView.hasImportSourceAccess(missingFile, securityScopeGranted: true))
    #expect(!AudioDBView.hasImportSourceAccess(missingFile, securityScopeGranted: false))
}

// MARK: - Audio tree builder

@Test func audioTreeBuilderBuildsNestedDirectoryStructure() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let albumA = root.appendingPathComponent("Album A", isDirectory: true)
    let albumB = root.appendingPathComponent("Album B", isDirectory: true)
    let disc1 = albumB.appendingPathComponent("Disc 1", isDirectory: true)
    try FileManager.default.createDirectory(at: albumA, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: disc1, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: albumA.appendingPathComponent("01.mp3"))
    try Data("audio".utf8).write(to: disc1.appendingPathComponent("track.flac"))
    try Data("audio".utf8).write(to: root.appendingPathComponent("bonus.mp3"))

    let children = AudioTreeBuilder.buildRootChildren(from: root)

    // 目录优先，再文件；同层按名称本地化排序。
    #expect(children.map(\.name) == ["Album A", "Album B", "bonus.mp3"])
    #expect(children.map(\.isDirectory) == [true, true, false])

    let albumBNode = try #require(children.first { $0.name == "Album B" })
    #expect(albumBNode.children?.map(\.name) == ["Disc 1"])
    #expect(albumBNode.childCount == 1)
    #expect(albumBNode.isExpandable)

    let disc1Node = try #require(albumBNode.children?.first)
    #expect(disc1Node.children?.map(\.name) == ["track.flac"])
    #expect(disc1Node.isExpandable)

    let fileNode = try #require(children.first { $0.name == "bonus.mp3" })
    #expect(fileNode.isDirectory == false)
    #expect(fileNode.childCount == 0)
    #expect(!fileNode.isExpandable)
}

@Test func audioTreeBuilderSkipsHiddenAndUnsupportedFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: root.appendingPathComponent("track.mp3"))
    try Data("hidden".utf8).write(to: root.appendingPathComponent(".hidden.mp3"))
    try Data("notes".utf8).write(to: root.appendingPathComponent("notes.txt"))
    try Data("cover".utf8).write(to: root.appendingPathComponent("cover.jpg"))

    let children = AudioTreeBuilder.buildRootChildren(from: root)

    #expect(children.map(\.name) == ["track.mp3"])
    #expect(AudioTreeBuilder.isSupportedAudioFile(root.appendingPathComponent("Track.MP3")))
    #expect(!AudioTreeBuilder.isSupportedAudioFile(root.appendingPathComponent("notes.txt")))
}

@Test func audioTreeBuilderReturnsEmptyForMissingRoot() {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    #expect(AudioTreeBuilder.buildRootChildren(from: root).isEmpty)
}


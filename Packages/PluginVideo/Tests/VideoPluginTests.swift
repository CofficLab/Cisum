
@testable import PluginVideo
import SwiftUI
import Testing

@MainActor
@Test func videoViewsCanBeConstructed() {
    let file = URL(fileURLWithPath: "/tmp/sample.mov")
    _ = VideoDB(files: [file])
    _ = VideoGrid(files: [file])
}

@Test func videoGridEmptyStateExplainsMissingVideos() {
    #expect(VideoGrid.emptyStateTitleKey == "Video")
    #expect(VideoGrid.emptyStateDescriptionKey == "No video files available")
}

@Test func videoTileOnlyAppliesCurrentFileSize() {
    let first = URL(fileURLWithPath: "/tmp/cisum-video-tests/first.mov")
    let second = URL(fileURLWithPath: "/tmp/cisum-video-tests/second.mov")

    #expect(VideoFileSizeLoadPolicy.shouldApplySize(currentFile: first, requestedFile: first))
    #expect(!VideoFileSizeLoadPolicy.shouldApplySize(currentFile: second, requestedFile: first))
}

@Test func videoTileAppliesFileSizeForSymlinkedCurrentFile() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let realFile = root.appendingPathComponent("real.mov")
    let linkedFile = root.appendingPathComponent("linked.mov")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("video".utf8).write(to: realFile)
    try FileManager.default.createSymbolicLink(at: linkedFile, withDestinationURL: realFile)

    #expect(VideoFileSizeLoadPolicy.shouldApplySize(
        currentFile: realFile,
        requestedFile: linkedFile
    ))
}

@Test func videoTileDoesNotApplyFileSizeAcrossDistinctDanglingSymlinks() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let missingFile = root.appendingPathComponent("missing.mov")
    let firstLink = root.appendingPathComponent("first.mov")
    let secondLink = root.appendingPathComponent("second.mov")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: firstLink, withDestinationURL: missingFile)
    try FileManager.default.createSymbolicLink(at: secondLink, withDestinationURL: missingFile)

    #expect(!VideoFileSizeLoadPolicy.shouldApplySize(
        currentFile: secondLink,
        requestedFile: firstLink
    ))
}

@Test func videoTileHidesOpenActionForMissingLocalFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let existingFile = root.appendingPathComponent("existing.mov")
    let missingFile = root.appendingPathComponent("missing.mov")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("video".utf8).write(to: existingFile)

    #expect(VideoFileActionPolicy.canOpen(existingFile))
    #expect(!VideoFileActionPolicy.canOpen(missingFile))
}

@Test func videoTileSelectionUsesReadableAccessibilityLabel() {
    #expect(VideoTileAccessibilityPolicy.selectionLabel(fileTitle: "Demo.mov") == "Select Demo.mov")
}

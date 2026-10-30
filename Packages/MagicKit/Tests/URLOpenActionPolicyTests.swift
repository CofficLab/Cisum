import Foundation
import Testing
@testable import MagicKit

@Test func revealInFinderOnlyAllowsLocalPaths() throws {
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

    #expect(URLOpenActionPolicy.canRevealInFinder(existingFile))
    #expect(URLOpenActionPolicy.canRevealInFinder(danglingLink))
    #expect(!URLOpenActionPolicy.canRevealInFinder(missingFile))
    #expect(!URLOpenActionPolicy.canRevealInFinder(URL(string: "https://example.com")!))
}

@Test func openButtonAccessibilityLabelDescribesTarget() throws {
    let localFile = URL(fileURLWithPath: "/tmp/Cisum Sample/track.mp3")
    let remoteURL = URL(string: "https://example.com/media/track.mp3")!

    #expect(URLOpenActionPolicy.buttonAccessibilityLabel(for: localFile) == "Open track.mp3")
    #expect(URLOpenActionPolicy.buttonAccessibilityLabel(for: remoteURL) == "Open example.com")
}

@Test func finderPresentationOpensDirectoryItselfInsteadOfItsParent() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let repository = root.appendingPathComponent("audios", isDirectory: true)
    let track = repository.appendingPathComponent("track.mp3")
    let missing = repository.appendingPathComponent("missing.mp3")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
    try Data("audio".utf8).write(to: track)

    // 目录必须被「打开」：在父目录中选中只会让访达停在父目录。
    #expect(URLOpenActionPolicy.finderPresentation(for: repository) == .openDirectory)
    // 文件仍然走「在父目录中选中」。
    #expect(URLOpenActionPolicy.finderPresentation(for: track) == .revealInParent)
    #expect(URLOpenActionPolicy.finderPresentation(for: missing) == .none)
    #expect(URLOpenActionPolicy.finderPresentation(for: URL(string: "https://example.com")!) == .none)
}

@Test func finderPresentationTreatsSymlinkToDirectoryAsDirectory() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let repository = root.appendingPathComponent("audios", isDirectory: true)
    let linkToDirectory = root.appendingPathComponent("audios-link")
    let danglingLink = root.appendingPathComponent("dangling")
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: linkToDirectory, withDestinationURL: repository)
    try FileManager.default.createSymbolicLink(
        at: danglingLink,
        withDestinationURL: root.appendingPathComponent("deleted-target")
    )

    // 指向目录的符号链接按目录处理。
    #expect(URLOpenActionPolicy.finderPresentation(for: linkToDirectory) == .openDirectory)
    // 悬空符号链接按文件处理：在父目录中选中它。
    #expect(URLOpenActionPolicy.finderPresentation(for: danglingLink) == .revealInParent)
}

@Test func directorySizeAndCountSkipHiddenFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let nested = root.appendingPathComponent("nested", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try Data("12345".utf8).write(to: root.appendingPathComponent("one.txt"))
    try Data("123".utf8).write(to: nested.appendingPathComponent("two.txt"))
    try Data("hidden".utf8).write(to: nested.appendingPathComponent(".hidden.txt"))

    #expect(root.filesCountRecursively() == 2)
    #expect(root.getSize() == 8)
    #expect(root.flatten().map(\.lastPathComponent).sorted() == ["one.txt", "two.txt"])
}

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

/// 平台能力判定：只有桌面端提供「用系统文件管理器打开本地目录」。
///
/// 这是全仓「打开仓库目录 / 在访达中显示」类入口的**唯一判断真源**。
/// iOS / visionOS 上打开应用沙盒目录必然失败（容器目录没有暴露给
/// 「文件」App），因此入口必须整条隐藏——留着按钮点了没反应，
/// 比没有按钮更糟。
///
/// 这条断言同时锁住两件事：
/// 1. 判定结果与当前构建平台一致；
/// 2. 两个入口名同义，避免调用点各写各的判断再次走偏。
@Test func fileManagerEntryIsOnlyOfferedOnDesktopPlatforms() {
    #if os(macOS)
    #expect(URLOpenActionPolicy.supportsSystemFileManager)
    #expect(URLOpenActionPolicy.shouldOfferFileManagerEntry)
    #else
    #expect(!URLOpenActionPolicy.supportsSystemFileManager)
    #expect(!URLOpenActionPolicy.shouldOfferFileManagerEntry)
    #endif

    // 别名必须与真源同值：调用点问「该不该展示」，
    // 底层问「平台支不支持」，两者不能各说各话。
    #expect(URLOpenActionPolicy.shouldOfferFileManagerEntry == URLOpenActionPolicy.supportsSystemFileManager)
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

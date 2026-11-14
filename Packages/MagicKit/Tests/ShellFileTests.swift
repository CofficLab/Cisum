import Foundation
import Testing
@testable import MagicKit

#if os(macOS)
@Test func shellFileMakeFileWritesLiteralContent() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let file = directory.appendingPathComponent("literal content.txt")
    let content = #"""
literal $HOME `uname` "quote" \ slash
second line
"""#

    ShellFile().makeFile(file.path, content: content)

    let saved = try String(contentsOf: file, encoding: .utf8)
    #expect(saved == content)
}

@Test func shellFileCommandsPreserveLiteralPaths() {
    let path = #"/tmp/song $HOME `uname` "quote" and 'single quote'.txt"#
    let source = #"/tmp/source $HOME `uname` "quote" and 'single quote'.txt"#
    let destination = #"/tmp/destination $HOME `uname` "quote" and 'single quote'.txt"#
    let quotedPath = ShellFile.shellQuoted(path)
    let quotedSource = ShellFile.shellQuoted(source)
    let quotedDestination = ShellFile.shellQuoted(destination)

    #expect(ShellFile.isDirExistsCommand(path).contains("[ ! -d \(quotedPath) ]"))
    #expect(ShellFile.isFileExistsCommand(path).contains("[ ! -f \(quotedPath) ]"))
    #expect(ShellFile.makeDirCommand(path).contains("mkdir -p -- \(quotedPath)"))
    #expect(ShellFile.getFileContentCommand(path) == "cat -- \(quotedPath)")
    #expect(ShellFile.removeCommand(path) == "rm -rf -- \(quotedPath)")
    #expect(ShellFile.copyCommand(source, to: destination) == "cp -r -- \(quotedSource) \(quotedDestination)")
    #expect(ShellFile.moveCommand(source, to: destination) == "mv -- \(quotedSource) \(quotedDestination)")
    #expect(ShellFile.getFileSizeCommand(path) == "stat -f%z -- \(quotedPath)")
    #expect(ShellFile.listFilesCommand(path) == "ls -1 -- \(quotedPath)")
    #expect(ShellFile.getPermissionsCommand(path) == "stat -f%Sp -- \(quotedPath)")
    #expect(ShellFile.changePermissionsCommand(path, permissions: "600") == "chmod '600' \(quotedPath)")
    #expect(ShellFile.changePermissionsCommand("--relative.txt", permissions: "600") == "chmod '600' './--relative.txt'")
}

@Test func shellFileCommandsHandleLeadingDashPaths() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let shellFile = ShellFile()
    shellFile.makeDir(directory.path)

    let source = directory.appendingPathComponent("--source.txt")
    let copy = directory.appendingPathComponent("--copy.txt")
    let moved = directory.appendingPathComponent("--moved.txt")
    try "content\n".write(to: source, atomically: true, encoding: .utf8)

    #expect(try shellFile.getFileContent(source.path) == "content")
    #expect(try shellFile.getFileSize(source.path) > 0)
    #expect(try shellFile.getPermissions(source.path).hasPrefix("-"))

    try shellFile.copy(source.path, to: copy.path)
    #expect(try shellFile.getFileContent(copy.path) == "content")

    try shellFile.move(copy.path, to: moved.path)
    #expect(shellFile.isFileExists(moved.path))
    #expect(!shellFile.isFileExists(copy.path))

    try shellFile.changePermissions(moved.path, permissions: "600")
    try shellFile.remove(moved.path)
    #expect(!shellFile.isFileExists(moved.path))

    #expect(try shellFile.listFiles(directory.path).contains("--source.txt"))
}
#endif

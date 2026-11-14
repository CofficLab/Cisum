import Foundation
import Testing
@testable import MagicKit

#if os(macOS)
@Test func shellGitAddCommandsUsePathspecSeparator() {
    let file = "--looks-like-an-option.txt"
    let quotedFile = ShellGit.shellQuoted(file)

    #expect(ShellGit.addCommand() == "git add -- .")
    #expect(ShellGit.resetStagedCommand() == "git reset -- .")
    #expect(ShellGit.addCommand([file]) == "git add -- \(quotedFile)")
    #expect(ShellGit.resetStagedCommand([file]) == "git reset -- \(quotedFile)")
}

@Test func shellGitAddAndResetPreserveLiteralFileNames() throws {
    let repo = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: repo)
    }

    try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    _ = try Shell.runSync("git init", at: repo.path)

    let fileName = #"literal $HOME `uname` "quote" and 'single quote'.txt"#
    let file = repo.appendingPathComponent(fileName)
    try "content\n".write(to: file, atomically: true, encoding: .utf8)

    try ShellGit.add([fileName], at: repo.path)
    #expect(try ShellGit.stagedFiles(at: repo.path) == [fileName])

    try ShellGit.reset([fileName], at: repo.path)
    #expect(try ShellGit.stagedFiles(at: repo.path).isEmpty)
    #expect(try ShellGit.unstagedFiles(at: repo.path).contains(fileName))
}

@Test func shellGitAddAndResetHandleLeadingDashFileNames() throws {
    let repo = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: repo)
    }

    try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    _ = try Shell.runSync("git init", at: repo.path)

    let fileName = "--looks-like-an-option.txt"
    let file = repo.appendingPathComponent(fileName)
    try "content\n".write(to: file, atomically: true, encoding: .utf8)

    try ShellGit.add([fileName], at: repo.path)
    #expect(try ShellGit.stagedFiles(at: repo.path) == [fileName])

    try ShellGit.reset([fileName], at: repo.path)
    #expect(try ShellGit.stagedFiles(at: repo.path).isEmpty)
    #expect(try ShellGit.unstagedFiles(at: repo.path).contains(fileName))
}
#endif

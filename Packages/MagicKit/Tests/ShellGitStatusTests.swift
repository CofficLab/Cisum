import Foundation
import Testing
@testable import MagicKit

#if os(macOS)
@Test func shellGitUnstagedFilesIncludesUntrackedFiles() throws {
    let repo = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: repo)
    }

    try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    _ = try Shell.runSync("git init", at: repo.path)

    let fileName = "new notes.txt"
    try "draft\n".write(
        to: repo.appendingPathComponent(fileName),
        atomically: true,
        encoding: .utf8
    )

    #expect(try ShellGit.hasUncommittedChanges(at: repo.path))
    #expect(try ShellGit.unstagedFiles(at: repo.path) == [fileName])
}

@Test func shellGitUnstagedPorcelainParserIgnoresStagedOnlyRows() {
    #expect(ShellGit.parseUnstagedFile(fromPorcelainLine: "A  staged.txt") == nil)
    #expect(ShellGit.parseUnstagedFile(fromPorcelainLine: " M changed.txt") == "changed.txt")
    #expect(ShellGit.parseUnstagedFile(fromPorcelainLine: "AM staged-and-changed.txt") == "staged-and-changed.txt")
    #expect(ShellGit.parseUnstagedFile(fromPorcelainLine: "?? untracked.txt") == "untracked.txt")
}

@Test func shellGitUnstagedPorcelainZParserSkipsRenameSourceRecords() {
    let output = "RM new name.txt\0old name.txt\0?? notes.txt\0"

    #expect(ShellGit.parseUnstagedFiles(fromPorcelainZOutput: output) == ["new name.txt", "notes.txt"])
}

@Test func shellGitUnstagedPorcelainZParserSkipsWorktreeRenameSourceRecords() {
    let output = " R new name.md\u{0}old name.md\u{0} M edited.md\u{0}"

    #expect(ShellGit.parseUnstagedFiles(fromPorcelainZOutput: output) == [
        "new name.md",
        "edited.md",
    ])
}

@Test func shellGitUnstagedFilesUseRenamedDestinationOnly() throws {
    let repo = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: repo)
    }

    try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    _ = try Shell.runSync("git init", at: repo.path)
    _ = try Shell.runSync("git config user.name Test", at: repo.path)
    _ = try Shell.runSync("git config user.email test@example.com", at: repo.path)

    let oldName = "old name.txt"
    let newName = "new $HOME `uname` name.txt"
    try "before\n".write(
        to: repo.appendingPathComponent(oldName),
        atomically: true,
        encoding: .utf8
    )
    try ShellGit.add([oldName], at: repo.path)
    _ = try ShellGit.commit(message: "initial", at: repo.path)

    _ = try Shell.runSync("git mv \(ShellGit.shellQuoted(oldName)) \(ShellGit.shellQuoted(newName))", at: repo.path)
    try "after\n".write(
        to: repo.appendingPathComponent(newName),
        atomically: false,
        encoding: .utf8
    )

    #expect(try ShellGit.unstagedFiles(at: repo.path) == [newName])
}
#endif

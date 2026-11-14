import Foundation
import Testing
@testable import MagicKit

#if os(macOS)
@Test func shellGitStashPreservesLiteralMessage() throws {
    let repo = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: repo)
    }

    try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    _ = try Shell.runSync("git init", at: repo.path)
    _ = try Shell.runSync("git config user.name Test", at: repo.path)
    _ = try Shell.runSync("git config user.email test@example.com", at: repo.path)

    let file = repo.appendingPathComponent("file.txt")
    try "before\n".write(to: file, atomically: true, encoding: .utf8)
    try ShellGit.add(["file.txt"], at: repo.path)
    _ = try ShellGit.commit(message: "initial", at: repo.path)

    try "after\n".write(to: file, atomically: true, encoding: .utf8)
    let message = #"literal $HOME `uname` "quote" and 'single quote'"#
    _ = try ShellGit.stash(message, at: repo.path)

    let list = try ShellGit.stashList(at: repo.path)
    #expect(list.contains(message))
}
#endif

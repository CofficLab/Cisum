import Foundation
import Testing
@testable import MagicKit

#if os(macOS)
@Test func shellGitCommitPreservesLiteralMessage() throws {
    let repo = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: repo)
    }

    try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    _ = try Shell.runSync("git init", at: repo.path)
    _ = try Shell.runSync("git config user.name Test", at: repo.path)
    _ = try Shell.runSync("git config user.email test@example.com", at: repo.path)

    try "hello\n".write(
        to: repo.appendingPathComponent("file.txt"),
        atomically: true,
        encoding: .utf8
    )
    try ShellGit.add(["file.txt"], at: repo.path)

    let message = #"literal $HOME `uname` "quote" and 'single quote'"#
    _ = try ShellGit.commit(message: message, at: repo.path)

    let subject = try Shell.runSync("git log -1 --pretty=%s", at: repo.path)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(subject == message)
}
#endif

import Foundation
import Testing
@testable import MagicKit

#if os(macOS)
@Test func shellGitBranchPreservesLiteralBranchNames() throws {
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
    try "content\n".write(to: file, atomically: true, encoding: .utf8)
    try ShellGit.add(["file.txt"], at: repo.path)
    let commitHash = try ShellGit.commit(message: "initial", at: repo.path)

    let branch = "feature/$HOME-`uname`"
    _ = try ShellGit.createBranch(branch, at: repo.path)

    #expect(try ShellGit.localBranches(at: repo.path).contains(branch))
    #expect(try ShellGit.lastCommitOfBranch(branch, at: repo.path).contains(commitHash.prefix(7)))

    _ = try ShellGit.deleteBranch(branch, force: true, at: repo.path)
    #expect(!((try ShellGit.localBranches(at: repo.path)).contains(branch)))
}
#endif

import Foundation
import Testing
@testable import MagicKit

#if os(macOS)
@Test func shellGitCheckoutFilesCommandSkipsEmptySelection() {
    let file = "--looks-like-an-option.txt"
    let quotedFile = ShellGit.shellQuoted(file)

    #expect(ShellGit.checkoutFilesCommand([]) == nil)
    #expect(ShellGit.checkoutFilesCommand([file]) == "git checkout -- \(quotedFile)")
}

@Test func shellGitCheckoutPreservesLiteralBranchAndFileNames() throws {
    let repo = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: repo)
    }

    try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    _ = try Shell.runSync("git init", at: repo.path)
    _ = try Shell.runSync("git config user.name Test", at: repo.path)
    _ = try Shell.runSync("git config user.email test@example.com", at: repo.path)

    let fileName = #"literal $HOME `uname` "quote" and 'single quote'.txt"#
    let file = repo.appendingPathComponent(fileName)
    try "before\n".write(to: file, atomically: true, encoding: .utf8)
    _ = try Shell.runSync("git add -- \(ShellGit.shellQuoted(fileName))", at: repo.path)
    _ = try ShellGit.commit(message: "initial", at: repo.path)
    let baseBranch = try ShellGit.currentBranch(at: repo.path)

    let branch = "feature/$HOME-`uname`"
    _ = try ShellGit.checkoutNewBranch(branch, at: repo.path)
    #expect(try ShellGit.currentBranch(at: repo.path) == branch)

    try "after\n".write(to: file, atomically: true, encoding: .utf8)
    _ = try ShellGit.checkoutFile(fileName, at: repo.path)
    #expect(try String(contentsOf: file, encoding: .utf8) == "before\n")

    try "after again\n".write(to: file, atomically: true, encoding: .utf8)
    _ = try ShellGit.checkoutFiles([fileName], at: repo.path)
    #expect(try String(contentsOf: file, encoding: .utf8) == "before\n")

    _ = try ShellGit.checkout(baseBranch, at: repo.path)
    _ = try ShellGit.checkoutForce(branch, at: repo.path)
    #expect(try ShellGit.currentBranch(at: repo.path) == branch)
}

@Test func shellGitCheckoutFilesNoOpsForEmptySelection() throws {
    let repo = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: repo)
    }

    try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    _ = try Shell.runSync("git init", at: repo.path)
    _ = try Shell.runSync("git config user.name Test", at: repo.path)
    _ = try Shell.runSync("git config user.email test@example.com", at: repo.path)

    let fileName = "note.txt"
    let file = repo.appendingPathComponent(fileName)
    try "before\n".write(to: file, atomically: true, encoding: .utf8)
    _ = try ShellGit.add([fileName], at: repo.path)
    _ = try ShellGit.commit(message: "initial", at: repo.path)

    try "after\n".write(to: file, atomically: true, encoding: .utf8)
    #expect(try ShellGit.checkoutFiles([], at: repo.path) == "")
    #expect(try String(contentsOf: file, encoding: .utf8) == "after\n")
}
#endif

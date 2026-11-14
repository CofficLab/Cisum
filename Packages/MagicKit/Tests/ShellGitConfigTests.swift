import Foundation
import Testing
@testable import MagicKit

#if os(macOS)
@Test func shellGitConfigUserPreservesLiteralValues() throws {
    let repo = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: repo)
    }

    try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    _ = try Shell.runSync("git init", at: repo.path)

    let name = #"literal $HOME `uname` "quote" and 'single quote'"#
    let email = #"literal+$HOME`uname`"quote"'single'@example.com"#
    _ = try ShellGit.configUser(name: name, email: email, at: repo.path)

    #expect(try ShellGit.userName(at: repo.path) == name)
    #expect(try ShellGit.userEmail(at: repo.path) == email)
}
#endif

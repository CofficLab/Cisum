import Foundation
import Testing
@testable import MagicKit

#if os(macOS)
@Suite struct ShellGitResetTests {
@Test func shellGitResetCommandsPreserveLiteralFileAndRefNames() {
    let fileName = #"literal $HOME `uname` "quote" and 'single quote'.txt"#
    let branch = "feature/$HOME-`uname`"

    #expect(
        ShellGit.resetCommand(files: [fileName], mode: "--mixed")
        == "git reset \(ShellGit.shellQuoted("--mixed")) -- \(ShellGit.shellQuoted(fileName))"
    )
    #expect(
        ShellGit.resetToCommitCommand(mode: "--mixed", target: branch)
        == "git reset --mixed \(ShellGit.shellQuoted(branch))"
    )
    #expect(
        ShellGit.resetFileCommand(fileName)
        == "git reset HEAD \(ShellGit.shellQuoted(fileName))"
    )
}
}
#endif

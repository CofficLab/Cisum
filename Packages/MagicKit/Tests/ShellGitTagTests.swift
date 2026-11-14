import Foundation
import Testing
@testable import MagicKit

#if os(macOS)
@Test func shellGitTagPreservesLiteralMessage() throws {
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
    _ = try ShellGit.commit(message: "initial", at: repo.path)

    let tagName = "release/test-tag"
    let message = #"literal $HOME `uname` "quote" and 'single quote'"#
    _ = try ShellGit.createTag(tagName, message: message, at: repo.path)

    let subject = try Shell.runSync("git for-each-ref refs/tags/release/test-tag --format='%(subject)'", at: repo.path)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let listed = try #require(try ShellGit.tagList(at: repo.path).first { $0.name == tagName })

    #expect(subject == message)
    #expect(listed.message == message)
}

@Test func shellGitTagCommandsPreserveLiteralRefs() {
    let tag = #"release/$HOME-`uname`-"quote"-'single'"#
    let message = #"literal $HOME `uname` "quote" and 'single quote'"#
    let commit = #"HEAD^{/fix $HOME `uname`}"#
    let quotedTag = ShellGit.shellQuoted(tag)
    let quotedMessage = ShellGit.shellQuoted(message)
    let quotedCommit = ShellGit.shellQuoted(commit)
    let quotedTagRef = ShellGit.shellQuoted("refs/tags/\(tag)")

    #expect(ShellGit.createTagCommand(tag, message: message) == "git tag -a \(quotedTag) -m \(quotedMessage)")
    #expect(ShellGit.createTagCommand(tag) == "git tag \(quotedTag)")
    #expect(ShellGit.deleteTagCommand(tag) == "git tag -d \(quotedTag)")
    #expect(ShellGit.tagsForCommitCommand(commit) == "git tag --points-at \(quotedCommit)")
    #expect(ShellGit.tagCommitHashCommand(tag) == "git rev-list -n 1 \(quotedTag)")
    #expect(ShellGit.tagInfoCommand(tag) == "git for-each-ref \(quotedTagRef) --format='%(taggername)::%(taggerdate)::%(subject)'")
}
#endif

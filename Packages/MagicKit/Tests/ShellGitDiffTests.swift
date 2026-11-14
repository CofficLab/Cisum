import Foundation
import Testing
@testable import MagicKit

#if os(macOS)
@Test func shellGitNameStatusParserUsesNewPathForRenamesAndCopies() throws {
    let renamed = try #require(ShellGit.parseNameStatusLine("R100\told/name.md\tnew/name.md"))
    let copied = try #require(ShellGit.parseNameStatusLine("C075\tsource.md\tcopy.md"))

    #expect(renamed.changeType == "R100")
    #expect(renamed.file == "new/name.md")
    #expect(copied.changeType == "C075")
    #expect(copied.file == "copy.md")
}

@Test func shellGitNameStatusParserUsesPathForSimpleChanges() throws {
    let modified = try #require(ShellGit.parseNameStatusLine("M\tSources/App.swift"))
    let deleted = try #require(ShellGit.parseNameStatusLine("D\tOld.swift"))

    #expect(modified.file == "Sources/App.swift")
    #expect(deleted.file == "Old.swift")
}

@Test func shellGitNameStatusParserSkipsMalformedRows() {
    #expect(ShellGit.parseNameStatusLine("M") == nil)
    #expect(ShellGit.parseNameStatusLine("\tfile.swift") == nil)
    #expect(ShellGit.parseNameStatusLine("R100\told.swift\t") == nil)
}

@Test func shellGitNameStatusZParserPreservesSpecialPaths() {
    let files = ShellGit.parseNameStatusZOutput(
        "M\u{0}folder/a\tfile.md\u{0}R100\u{0}old\nname.md\u{0}new\tname.md\u{0}"
    )

    #expect(files.count == 2)
    #expect(files[0].changeType == "M")
    #expect(files[0].file == "folder/a\tfile.md")
    #expect(files[1].changeType == "R100")
    #expect(files[1].file == "new\tname.md")
}

@Test func shellGitDiffHandlesQuotedFilePaths() async throws {
    let repo = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: repo)
    }

    try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    _ = try Shell.runSync("git init", at: repo.path)
    _ = try Shell.runSync("git config user.name Test", at: repo.path)
    _ = try Shell.runSync("git config user.email test@example.com", at: repo.path)

    let fileName = "folder/a\tfile 'quoted'.txt"
    let fileURL = repo.appendingPathComponent(fileName)
    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "before\n".write(to: fileURL, atomically: true, encoding: .utf8)
    _ = try Shell.runSync("git add .", at: repo.path)
    _ = try Shell.runSync("git commit -m initial", at: repo.path)

    try "after\n".write(to: fileURL, atomically: true, encoding: .utf8)

    let directDiff = try ShellGit.diffFile(fileName, at: repo.path)
    let listedDiff = try await ShellGit.diffFileList(at: repo.path)
    let contentChange = try ShellGit.uncommittedFileContentChange(file: fileName, repoPath: repo.path)

    #expect(directDiff.contains("-before"))
    #expect(directDiff.contains("+after"))
    #expect(listedDiff.map { $0.file } == [fileName])
    #expect(listedDiff.first?.diff.contains("+after") == true)
    #expect(contentChange.before == "before")
    #expect(contentChange.after == "after\n")
}

@Test func shellGitDiffCommandsPreserveLiteralRefsAndPaths() {
    let from = #"HEAD~1 $HOME `uname`"#
    let to = #"feature/$HOME-`uname`-"quote"-'single'"#
    let commit = #"HEAD^{/fix $HOME `uname`}"#
    let file = #"folder/a file $HOME `uname` "quote" 'single'.txt"#
    let quotedFrom = ShellGit.shellQuoted(from)
    let quotedTo = ShellGit.shellQuoted(to)
    let quotedCommit = ShellGit.shellQuoted(commit)
    let quotedCommitFile = ShellGit.shellQuoted("\(commit):\(file)")
    let quotedParent = ShellGit.shellQuoted("\(commit)^")
    let quotedFile = ShellGit.shellQuoted(file)

    #expect(ShellGit.diffBetweenCommitsCommand(from: from, to: to) == "git diff \(quotedFrom) \(quotedTo)")
    #expect(ShellGit.fileExistsCommand(commit: commit, file: file) == "git cat-file -e \(quotedCommitFile)")
    #expect(ShellGit.parentCommitCommand(commit) == "git rev-parse \(quotedParent)")
    #expect(ShellGit.fileContentCommand(commit: commit, file: file) == "git show \(quotedCommitFile)")
    #expect(ShellGit.diffTreeNameStatusCommand(commit) == "git diff-tree --no-commit-id --name-status -z -r \(quotedCommit)")
    #expect(ShellGit.diffTreeNameOnlyCommand(commit) == "git diff-tree --no-commit-id --name-only -z -r \(quotedCommit)")
    #expect(ShellGit.revListParentsCommand(commit) == "git rev-list --parents -n 1 \(quotedCommit)")
    #expect(ShellGit.showCommitFileDiffCommand(commit: commit, file: file) == "git show \(quotedCommit) -- \(quotedFile)")
    #expect(ShellGit.showNameOnlyCommand(commit) == "git show --name-only --format= \(quotedCommit)")
}

@Test func shellGitWorkingDirectoryReadsStayInsideRepository() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let repo = root.appendingPathComponent("repo", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    try "inside\n".write(to: repo.appendingPathComponent("inside.txt"), atomically: true, encoding: .utf8)
    try "outside\n".write(to: root.appendingPathComponent("outside.txt"), atomically: true, encoding: .utf8)

    #expect(try ShellGit.fileContentInWorkingDirectory(file: "inside.txt", at: repo.path) == "inside\n")
    #expect(throws: (any Error).self) {
        _ = try ShellGit.fileContentInWorkingDirectory(file: "../outside.txt", at: repo.path)
    }
    #expect(throws: (any Error).self) {
        _ = try ShellGit.workingDirectoryFileURL(file: "/tmp/outside.txt", repoPath: repo.path)
    }
}
#endif

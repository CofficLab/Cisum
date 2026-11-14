import Testing
@testable import MagicKit

#if os(macOS)
@Test func shellGitLogParserPreservesPipesInSubjects() throws {
    let commit = try #require(ShellGit.parseRecentCommitLine(
        "abc123|Author|author@example.com|1700000000|fix: keep A | B visible"
    ))

    #expect(commit.hash == "abc123")
    #expect(commit.message == "fix: keep A | B visible")
}

@Test func shellGitCommitDetailParserPreservesPipesInBody() throws {
    let detail = try ShellGit.parseCommitDetailOutput(
        "abc123|Author|author@example.com|1700000000|fix: subject|body keeps A | B"
    )

    #expect(detail.id == "abc123")
    #expect(detail.message == "fix: subject")
    #expect(detail.body == "body keeps A | B")
}

@Test func shellGitCommitDetailParserPreservesPipesInSubjects() throws {
    let detail = try ShellGit.parseCommitDetailOutput(
        "abc123\u{01}Author\u{01}author@example.com\u{01}1700000000\u{01}fix: keep A | B visible\u{01}body"
    )

    #expect(detail.id == "abc123")
    #expect(detail.message == "fix: keep A | B visible")
    #expect(detail.body == "body")
}

@Test func shellGitRecentCommitParserPreservesPipesWithSafeSeparator() throws {
    let commit = try #require(ShellGit.parseRecentCommitLine(
        "abc123\u{01}Author\u{01}author@example.com\u{01}1700000000\u{01}fix: keep A | B visible"
    ))

    #expect(commit.hash == "abc123")
    #expect(commit.message == "fix: keep A | B visible")
}

@Test func shellGitLogDecorationParserExtractsRealTagDecorations() {
    #expect(ShellGit.parseDecorationTags("(HEAD -> main, tag: v1.0.0, tag: release/2026.06, origin/main)") == [
        "v1.0.0",
        "release/2026.06",
    ])
    #expect(ShellGit.parseDecorationTags("tag: beta-1") == ["beta-1"])
    #expect(ShellGit.parseDecorationTags("(HEAD -> main, origin/main)") == [])
}

@Test func shellGitLogParserSkipsMalformedRecentCommitRows() {
    #expect(ShellGit.parseRecentCommitLine("abc123|Author|missing fields") == nil)
    #expect(ShellGit.parseRecentCommitLine("abc123|Author|author@example.com|not-a-time|subject") == nil)
    #expect(ShellGit.parseRecentCommitLine("abc123|Author|author@example.com|nan|subject") == nil)
}

@Test func shellGitCommitDetailParserRejectsInvalidTimestamp() {
    #expect(throws: (any Error).self) {
        try ShellGit.parseCommitDetailOutput(
            "abc123|Author|author@example.com|not-a-time|fix: subject|body"
        )
    }
}

@Test func shellGitISO8601DateParserRejectsMalformedDates() throws {
    let parsed = try #require(ShellGit.parseISO8601CommitDate("2026-06-01T00:00:00Z"))

    #expect(parsed.timeIntervalSince1970 == 1_780_272_000)
    #expect(ShellGit.parseISO8601CommitDate("not-a-date") == nil)
    #expect(ShellGit.parseISO8601CommitDate("") == nil)
}

@Test func shellGitLogCommandsPreserveLiteralRefs() {
    let branch = #"feature/$HOME-`uname`-"quote"-'single'"#
    let remote = #"origin $HOME `uname`"#
    let commit = #"HEAD^{/fix $HOME `uname`}"#
    let format = #"%H|%an|%s $HOME `uname`"#
    let quotedBranch = ShellGit.shellQuoted(branch)
    let quotedRemoteRange = ShellGit.shellQuoted("\(remote)/\(branch)..\(branch)")
    let quotedCommit = ShellGit.shellQuoted(commit)
    let quotedFormat = ShellGit.shellQuoted(format)

    #expect(ShellGit.commitsInBranchCommand(branch, count: 2, format: format) == "git log \(quotedBranch) -n 2 --pretty=format:\(quotedFormat)")
    #expect(ShellGit.recentCommitsCommand(count: 2, format: format) == "git log -n 2 --pretty=format:\(quotedFormat)")
    #expect(ShellGit.commitDetailCommand(commit, format: format) == "git show \(quotedCommit) --pretty=format:\(quotedFormat) --no-patch")
    #expect(ShellGit.commitShowCommand(commit) == "git show \(quotedCommit)")
    #expect(ShellGit.unpushedCommitsCommand(remote: remote, branchName: branch) == "git log \(quotedRemoteRange) --oneline")
    #expect(ShellGit.unpushedCommitListCommand(remote: remote, branchName: branch).hasPrefix("git log \(quotedRemoteRange) --pretty=format:"))
    #expect(ShellGit.commitsWithTagsCommand(limit: 2) == "git log --pretty=format:\(ShellGit.shellQuoted("%H%x09%s%x09%d")) -2")
    #expect(ShellGit.commitListCommand(limit: 2, format: format) == "git log --pretty=tformat:\(quotedFormat) -n 2")
    #expect(ShellGit.commitListWithPaginationCommand(skip: 4, size: 2, format: format) == "git log --pretty=tformat:\(quotedFormat) --skip=4 -n 2")
}

@Test func shellGitLogCommandsClampNegativeLimits() {
    let format = "%H|%s"

    #expect(ShellGit.logCommand(limit: -5, oneline: true) == "git log --oneline -0")
    #expect(ShellGit.logCommand(limit: -5, oneline: false) == "git log -0")
    #expect(ShellGit.commitsInBranchCommand("main", count: -5, format: format) == "git log 'main' -n 0 --pretty=format:'%H|%s'")
    #expect(ShellGit.recentCommitsCommand(count: -5, format: format) == "git log -n 0 --pretty=format:'%H|%s'")
    #expect(ShellGit.commitsWithTagsCommand(limit: -5) == "git log --pretty=format:'%H%x09%s%x09%d' -0")
    #expect(ShellGit.commitListCommand(limit: -5, format: format) == "git log --pretty=tformat:'%H|%s' -n 0")
    #expect(ShellGit.logsWithPaginationCommand(skip: -10, size: -5, oneline: true) == "git log --oneline --skip=0 -0")
    #expect(ShellGit.commitListWithPaginationCommand(skip: -10, size: -5, format: format) == "git log --pretty=tformat:'%H|%s' --skip=0 -n 0")
}

@Test func shellGitLogPaginationClampsNegativeSizeBeforeSkip() {
    let negativeSize = ShellGit.paginationArguments(page: 2, size: -20)
    #expect(negativeSize.skip == 0)
    #expect(negativeSize.size == 0)

    let overflowing = ShellGit.paginationArguments(page: Int.max, size: 2)
    #expect(overflowing.skip == Int.max)
    #expect(overflowing.size == 2)
}
#endif

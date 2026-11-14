import Testing
@testable import MagicKit

#if os(macOS)
@Test func shellGitMergeCommandsPreserveLiteralInputs() {
    let branch = #"feature/$HOME-`uname`-"quote"-'single'"#
    let message = #"merge $HOME `uname` "quote" and 'single quote'"#
    let strategy = #"recursive $HOME `uname`"#
    let files = [
        #"conflict $HOME `uname` "quote".txt"#,
        #"folder/'single quote'.txt"#
    ]
    let quotedBranch = ShellGit.shellQuoted(branch)
    let quotedMessage = ShellGit.shellQuoted(message)
    let quotedStrategy = ShellGit.shellQuoted(strategy)
    let quotedFiles = files.map(ShellGit.shellQuoted).joined(separator: " ")

    #expect(ShellGit.mergeCommand(branch) == "git merge \(quotedBranch)")
    #expect(ShellGit.mergeFastForwardCommand(branch) == "git merge --ff-only \(quotedBranch)")
    #expect(ShellGit.mergeNoFastForwardCommand(branch, message: message) == "git merge --no-ff \(quotedBranch) -m \(quotedMessage)")
    #expect(ShellGit.mergeNoFastForwardCommand(branch) == "git merge --no-ff \(quotedBranch)")
    #expect(ShellGit.mergeSquashCommand(branch) == "git merge --squash \(quotedBranch)")
    #expect(ShellGit.mergeWithStrategyCommand(branch, strategy: strategy) == "git merge -s \(quotedStrategy) \(quotedBranch)")
    #expect(ShellGit.mergeResolveOursCommand() == "git checkout --ours .")
    #expect(ShellGit.mergeResolveTheirsCommand() == "git checkout --theirs .")
    #expect(ShellGit.mergeResolveOursCommand(files) == "git checkout --ours -- \(quotedFiles)")
    #expect(ShellGit.mergeResolveTheirsCommand(files) == "git checkout --theirs -- \(quotedFiles)")
}

@Test func shellGitMergeStatusMessagesAreReadableEnglish() {
    #expect(ShellGit.mergeStatusMessage(isMerging: false, conflictFiles: []) == "Not currently merging")
    #expect(ShellGit.mergeStatusMessage(isMerging: true, conflictFiles: []) == "Merging with no conflict files")
    #expect(ShellGit.mergeStatusMessage(
        isMerging: true,
        conflictFiles: ["one.swift", "two.swift"]
    ) == "Merging with conflicts: one.swift, two.swift")
}
#endif

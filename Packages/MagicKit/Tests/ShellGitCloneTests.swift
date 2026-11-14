import Testing
@testable import MagicKit

#if os(macOS)
@Test func shellGitCloneCommandsPreserveLiteralInputs() {
    let url = #"https://example.com/$HOME/`repo` "quote".git"#
    let destination = #"/tmp/repo $HOME `uname` "quote" 'single'"#
    let branch = #"feature/$HOME-`uname`-"quote"-'single'"#
    let quotedURL = ShellGit.shellQuoted(url)
    let quotedDestination = ShellGit.shellQuoted(destination)
    let quotedBranch = ShellGit.shellQuoted(branch)

    #expect(ShellGit.cloneCommand(url, to: destination, branch: branch, depth: 1) == "git clone -b \(quotedBranch) --depth 1 \(quotedURL) \(quotedDestination)")
    #expect(ShellGit.cloneCommand(url) == "git clone \(quotedURL)")
    #expect(ShellGit.cloneRecursiveCommand(url, to: destination, branch: branch) == "git clone --recurse-submodules -b \(quotedBranch) \(quotedURL) \(quotedDestination)")
    #expect(ShellGit.cloneBareCommand(url, to: destination) == "git clone --bare \(quotedURL) \(quotedDestination)")
    #expect(ShellGit.cloneMirrorCommand(url, to: destination) == "git clone --mirror \(quotedURL) \(quotedDestination)")
    #expect(ShellGit.lsRemoteCommand(url) == "git ls-remote \(quotedURL)")
}
#endif

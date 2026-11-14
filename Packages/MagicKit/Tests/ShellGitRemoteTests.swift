import Testing
@testable import MagicKit

#if os(macOS)
@Test func shellGitRemoteCommandsPreserveLiteralInputs() {
    let remote = "origin-$HOME-`uname`"
    let branch = "feature/$HOME-`uname`"
    let url = #"https://example.com/literal $HOME `uname` "quote" and 'single quote'.git"#

    #expect(
        ShellGit.pushCommand(remote: remote, branch: branch)
        == "git push \(ShellGit.shellQuoted(remote)) \(ShellGit.shellQuoted(branch))"
    )
    #expect(
        ShellGit.pullCommand(remote: remote, branch: branch)
        == "git pull \(ShellGit.shellQuoted(remote)) \(ShellGit.shellQuoted(branch))"
    )
    #expect(
        ShellGit.addRemoteCommand(remote, url: url)
        == "git remote add \(ShellGit.shellQuoted(remote)) \(ShellGit.shellQuoted(url))"
    )
    #expect(
        ShellGit.removeRemoteCommand(remote)
        == "git remote remove \(ShellGit.shellQuoted(remote))"
    )
    #expect(
        ShellGit.setRemoteURLCommand(remote, url: url)
        == "git remote set-url \(ShellGit.shellQuoted(remote)) \(ShellGit.shellQuoted(url))"
    )
}

@Test func shellGitRemoteParserIgnoresMalformedVerboseRows() {
    let remotes = ShellGit.parseRemoteListOutput("""
    origin\thttps://github.com/example/app.git (fetch)
    origin\thttps://github.com/example/app.git (push)
    missing-tab https://example.com/repo.git (fetch)
    upstream\thttps://github.com/example/upstream.git
    mirror\thttps://github.com/example/mirror.git (mirror)
    backup\tssh://git@example.com/backup.git (push)
    """)

    #expect(remotes.count == 2)
    #expect(remotes[0] == MagicGitRemote(
        id: "origin",
        name: "origin",
        url: "https://github.com/example/app.git",
        fetchURL: "https://github.com/example/app.git",
        pushURL: "https://github.com/example/app.git",
        isDefault: true
    ))
    #expect(remotes[1] == MagicGitRemote(
        id: "backup",
        name: "backup",
        url: "ssh://git@example.com/backup.git",
        fetchURL: nil,
        pushURL: "ssh://git@example.com/backup.git",
        isDefault: false
    ))
}

@Test func shellGitRemoteParserPreservesSpacesInURLs() throws {
    let localURL = "/Users/example/Repos/My Project.git"
    let remotes = ShellGit.parseRemoteListOutput("""
    local\t\(localURL) (fetch)
    local\t\(localURL) (push)
    """)

    #expect(remotes.count == 1)
    let remote = try #require(remotes.first)
    #expect(remote.url == localURL)
    #expect(remote.fetchURL == localURL)
    #expect(remote.pushURL == localURL)
    #expect(ShellGit.parseFirstRemoteURL("local\t\(localURL) (fetch)\n") == localURL)
}
#endif

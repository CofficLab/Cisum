import Foundation
import Testing
@testable import MagicKit

#if os(macOS)
@Test func shellSystemCommandsPreserveLiteralInputs() {
    let value = #"/tmp/Cisum $HOME `uname` "quote" and 'single quote'"#
    let quoted = ShellSystem.shellQuoted(value)

    #expect(ShellSystem.diskUsageCommand(path: value) == "df -h -- \(quoted)")
    #expect(ShellSystem.processesCommand(named: value) == "ps aux | grep \(quoted) | grep -v grep")
    #expect(ShellSystem.commandExistsCommand(value) == "which \(quoted)")
}

@Test func shellSystemDiskUsageHandlesLeadingDashPaths() throws {
    #expect(ShellSystem.diskUsageCommand(path: "--disk-path") == "df -h -- './--disk-path'")

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(
        at: directory.appendingPathComponent("--disk-path", isDirectory: true),
        withIntermediateDirectories: true
    )

    let output = try Shell.runSync(ShellSystem.diskUsageCommand(path: "--disk-path"), at: directory.path)
    #expect(output.contains("Filesystem"))
}

@Test func shellSystemEnvironmentReadsWithoutShellExpansion() {
    #expect(ShellSystem.getEnvironmentVariable(#"PATH"; echo injected"#) == "")
}
#endif

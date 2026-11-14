import Foundation
import Testing
@testable import MagicKit

#if os(macOS)
@Test func shellProcessTopCommandsUseMacOSSortFlags() {
    #expect(ShellProcess.topProcessesCommand(sort: .cpu, count: 10) == "ps aux -r | head -11")
    #expect(ShellProcess.topProcessesCommand(sort: .memory, count: 5) == "ps aux -m | head -6")
}

@Test func shellProcessTopCommandsClampNegativeCount() {
    #expect(ShellProcess.topProcessesCommand(sort: .cpu, count: -3) == "ps aux -r | head -1")
    #expect(ShellProcess.topProcessesCommand(sort: .memory, count: -1) == "ps aux -m | head -1")
}

@Test func shellProcessCommandsPreserveLiteralInputs() {
    let name = #"App $HOME `uname` "quote" and 'single quote'"#
    let file = #"/tmp/file $HOME `uname` "quote" and 'single quote'.txt"#
    let pid = "123"
    let quotedName = ShellProcess.shellQuoted(name)
    let quotedFile = ShellProcess.shellQuoted(file)

    #expect(ShellProcess.findProcessesCommand(named: name) == "ps aux | grep \(quotedName) | grep -v grep")
    #expect(ShellProcess.findProcessCommand(pid: pid) == "ps -p 123 -o user,pid,%cpu,%mem,vsz,rss,tt,stat,start,time,command")
    #expect(ShellProcess.killProcessCommand(pid: pid) == "kill 123")
    #expect(ShellProcess.forceKillProcessCommand(pid: pid) == "kill -9 123")
    #expect(ShellProcess.killProcessesCommand(named: name) == "pkill \(quotedName)")
    #expect(ShellProcess.processTreeCommand(pid: pid) == "pstree 123")
    #expect(ShellProcess.launchAppCommand(name) == "open -a \(quotedName)")
    #expect(ShellProcess.launchAppCommand(name, withFile: file) == "open -a \(quotedName) \(quotedFile)")
    #expect(ShellProcess.isProcessRunningCommand(name) == "pgrep \(quotedName)")
    #expect(ShellProcess.processDetailsCommand(pid: pid) == "ps -p 123 -o pid,ppid,user,time,command")
    #expect(ShellProcess.monitorProcessCommand(pid: pid) == "top -pid 123 -l 1")
    #expect(ShellProcess.startServiceCommand(name) == "launchctl start \(quotedName)")
    #expect(ShellProcess.stopServiceCommand(name) == "launchctl stop \(quotedName)")
}

@Test func shellProcessCommandsRejectInvalidPIDs() {
    let invalidPIDs = ["", " ", "0", "-1", "abc", "123 abc", "１２３"]

    for pid in invalidPIDs {
        #expect(ShellProcess.normalizedPID(pid) == nil)
        #expect(ShellProcess.findProcessCommand(pid: pid) == nil)
        #expect(ShellProcess.killProcessCommand(pid: pid) == nil)
        #expect(ShellProcess.forceKillProcessCommand(pid: pid) == nil)
        #expect(ShellProcess.processTreeCommand(pid: pid) == nil)
        #expect(ShellProcess.processDetailsCommand(pid: pid) == nil)
        #expect(ShellProcess.monitorProcessCommand(pid: pid) == nil)
    }

    #expect(ShellProcess.normalizedPID(" 123\n") == "123")
}

@Test func shellProcessFindProcessUsesExactPIDLookup() {
    let currentPID = String(Foundation.ProcessInfo.processInfo.processIdentifier)
    let process = ShellProcess.findProcess(pid: currentPID)

    #expect(process?.pid == currentPID)
}

@Test func shellProcessTopQueriesReturnProcessesOnMacOS() {
    #expect(!ShellProcess.getTopCPUProcesses(count: 3).isEmpty)
    #expect(!ShellProcess.getTopMemoryProcesses(count: 3).isEmpty)
}
#endif

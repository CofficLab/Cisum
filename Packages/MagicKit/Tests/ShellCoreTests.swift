import Foundation
import Testing
@testable import MagicKit

#if os(macOS)
@Test func shellRunSyncHandlesConcurrentCallers() throws {
    let lock = NSLock()
    var outputs: [String] = []
    var failures: [Error] = []

    DispatchQueue.concurrentPerform(iterations: 24) { index in
        do {
            let output = try Shell.runSync("printf '%s' \(index)")
            lock.lock()
            outputs.append(output)
            lock.unlock()
        } catch {
            lock.lock()
            failures.append(error)
            lock.unlock()
        }
    }

    #expect(failures.isEmpty)
    #expect(Set(outputs) == Set((0..<24).map(String.init)))
}

@Test func shellCommandLookupQuotesUserInput() {
    let command = #"git; echo injected $HOME `uname` "quote" and 'single quote'"#
    let quotedCommand = Shell.shellQuoted(command)

    #expect(Shell.commandLookupCommand(command) == "which \(quotedCommand)")
    #expect(Shell.commandLookupCommand(" \n ") == nil)
}

@Test func shellCommandLookupDoesNotExpandShellSyntax() {
    let marker = UUID().uuidString
    let payload = #"definitely_missing_command'; echo \#(marker); echo '"#

    #expect(Shell.getCommandPath(payload) == nil)
    #expect(Shell.isCommandAvailable(payload) == false)
}
#endif

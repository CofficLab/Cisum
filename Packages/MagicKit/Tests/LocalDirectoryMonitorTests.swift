import XCTest
@testable import MagicKit

final class LocalDirectoryMonitorTests: XCTestCase {
    func testFileListChangeDetection() {
        let base = URL(fileURLWithPath: "/tmp/cisum-monitor-tests", isDirectory: true)
        let previous = [
            base.appendingPathComponent("a.mp3"),
            base.appendingPathComponent("b.mp3"),
        ]
        let current = [
            base.appendingPathComponent("a.mp3"),
            base.appendingPathComponent("b.mp3"),
            base.appendingPathComponent("c.mp3"),
        ]

        XCTAssertFalse(LocalDirectoryMonitor.hasFileListChanged(previous: previous, current: previous))
        XCTAssertTrue(LocalDirectoryMonitor.hasFileListChanged(previous: previous, current: current))
    }
}

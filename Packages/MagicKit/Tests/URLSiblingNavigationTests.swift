import Foundation
import Testing
@testable import MagicKit

struct URLSiblingNavigationTests {
    @Test
    func nextAndPreviousFileResolveCanonicalizedDirectoryEntries() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("URLSiblingNavigationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let first = root.appendingPathComponent("01.mp3")
        let second = root.appendingPathComponent("02.mp3")
        let third = root.appendingPathComponent("03.mp3")
        for url in [first, second, third] {
            try Data([0x01]).write(to: url)
        }

        #expect(second.getPrevFile()?.lastPathComponent == "01.mp3")
        #expect(second.getNextFile()?.lastPathComponent == "03.mp3")
        #expect(first.getPrevFile() == nil)
        #expect(third.getNextFile() == nil)
    }

    @Test
    func siblingNavigationReturnsNilWhenTheCurrentFileIsNotAChild() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("URLSiblingNavigationMissingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data([0x01]).write(to: root.appendingPathComponent("01.mp3"))

        let missing = root.appendingPathComponent("missing.mp3")
        #expect(missing.getPrevFile() == nil)
        #expect(missing.getNextFile() == nil)
    }
}

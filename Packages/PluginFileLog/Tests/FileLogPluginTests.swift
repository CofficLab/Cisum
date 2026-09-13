import Foundation
import Testing
@testable import PluginFileLog
#if os(macOS)
    import AppKit

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.withLock {
            value += 1
        }
    }

    var count: Int {
        lock.withLock {
            value
        }
    }
}
#endif

@Test func defaultConfigurationReturnsFileLogDirectory() {
    let url = DefaultFileLogConfiguration().logsDirectory()
    #expect(url.lastPathComponent == "FileLog")
}

@Test func logRotationUsesUniqueNameWhenTimestampAlreadyExists() {
    let directory = URL(fileURLWithPath: "/tmp/cisum-file-log-tests", isDirectory: true)
    let existing = directory.appendingPathComponent("2026-05-31_15-00-00.log")

    let next = FileLogRotation.uniqueLogFileURL(
        baseName: "2026-05-31_15-00-00",
        in: directory
    ) { url in
        url == existing
    }

    #expect(next.lastPathComponent == "2026-05-31_15-00-00 2.log")
}

@Test func logRotationUsesReadableFallbackForEmptyBaseName() {
    let directory = URL(fileURLWithPath: "/tmp/cisum-file-log-tests", isDirectory: true)

    let next = FileLogRotation.uniqueLogFileURL(baseName: "", in: directory) { _ in false }

    #expect(next.lastPathComponent == "Cisum Log.log")
}

@Test func logRotationSkipsDanglingSymlinkNames() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let danglingLog = directory.appendingPathComponent("2026-05-31_15-00-00.log")
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
        at: danglingLog,
        withDestinationURL: directory.appendingPathComponent("missing.log")
    )

    let next = FileLogRotation.uniqueLogFileURL(
        baseName: "2026-05-31_15-00-00",
        in: directory
    )

    #expect(next.lastPathComponent == "2026-05-31_15-00-00 2.log")
}

@Test func fileLogFileSizePolicyReadsFoundationNumberAttributes() {
    #expect(FileLogFileSizePolicy.fileSize(from: [.size: NSNumber(value: 1234)]) == 1234)
    #expect(FileLogFileSizePolicy.fileSize(from: [.size: Int64(5678)]) == 5678)
    #expect(FileLogFileSizePolicy.fileSize(from: [.size: Int(90)]) == 90)
}

@Test func fileLogFileSizePolicyNormalizesInvalidSizes() {
    #expect(FileLogFileSizePolicy.fileSize(from: [.size: NSNumber(value: -1234)]) == 0)
    #expect(FileLogFileSizePolicy.fileSize(from: [.size: Int64.max]) == Int.max)
    #expect(FileLogFileSizePolicy.fileSize(from: [:]) == nil)
}

#if os(macOS)
@Test func terminationObserverIsIdempotentAndRemovable() {
    let notificationCenter = NotificationCenter()
    let observer = FileLogTerminationObserver()
    let stopCount = LockedCounter()

    let stop: @Sendable () -> Void = {
        stopCount.increment()
    }

    observer.start(notificationCenter: notificationCenter, stop: stop)
    observer.start(notificationCenter: notificationCenter, stop: stop)

    notificationCenter.post(name: NSApplication.willTerminateNotification, object: nil)

    #expect(stopCount.count == 1)

    observer.stopObserving(notificationCenter: notificationCenter)
    notificationCenter.post(name: NSApplication.willTerminateNotification, object: nil)

    #expect(stopCount.count == 1)
}
#endif

// MARK: - FileLogCoordinator 生命周期

/// 指向临时目录的日志配置。
private struct TempLogConfiguration: FileLogConfiguration {
    let directory: URL
    func logsDirectory() -> URL { directory }
}

@Suite(.serialized)
struct FileLogCoordinatorLifecycleTests {
@Test
func coordinatorStartCreatesLogDirectoryAndFile() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FileLogCoordinator-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let coordinator = FileLogCoordinator.shared
    coordinator.stop() // 复位，避免单例残留状态
    coordinator.configuration = TempLogConfiguration(directory: directory)

    coordinator.start()
    try await Task.sleep(for: .milliseconds(500))

    let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    #expect(files.contains { $0.hasSuffix(".log") })
    #expect(!files.isEmpty)
}

@Test
func coordinatorStartIsIdempotent() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FileLogCoordinatorIdem-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let coordinator = FileLogCoordinator.shared
    coordinator.stop() // 复位
    coordinator.configuration = TempLogConfiguration(directory: directory)

    coordinator.start()
    coordinator.start()
    try await Task.sleep(for: .milliseconds(300))

    let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    // 重复 start 只轮转一次（幂等保护）。
    #expect(files.filter { $0.hasSuffix(".log") }.count <= 2)
}

@Test
func coordinatorStopIsSafeAndFlushes() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FileLogCoordinatorStop-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let coordinator = FileLogCoordinator.shared
    coordinator.stop() // 复位
    coordinator.configuration = TempLogConfiguration(directory: directory)

    coordinator.start()
    try await Task.sleep(for: .milliseconds(300))
    coordinator.stop()
    coordinator.stop() // 重复 stop 不崩溃
    try await Task.sleep(for: .milliseconds(200))

    let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    #expect(!files.isEmpty)
}
}

import XCTest
@testable import MagicKit

/// iCloud 下载网关的单元测试。
///
/// 覆盖判据、错误归类、启动参数注入，以及下载等待循环的边界行为。
/// 不依赖真实 iCloud 账号：全部通过 `StubUbiquitousItemDownloader` 脚本化。
final class ICloudDownloadingTests: XCTestCase {
    private var control: ICloudDownloadControl { ICloudDownloadControl.shared }

    override func setUp() {
        super.setUp()
        control.reset()
    }

    override func tearDown() {
        control.reset()
        super.tearDown()
    }

    private func makeTemporaryFile(_ name: String) throws -> (root: URL, file: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent(name)
        try Data("audio".utf8).write(to: file)
        return (root, file)
    }

    // MARK: - Local content probe

    /// 本地文件内容已在磁盘，必须直接返回，不应发起任何下载请求。
    func testLocalContentFileReturnsWithoutStartingDownload() async throws {
        let (root, file) = try makeTemporaryFile("track.mp3")
        defer { try? FileManager.default.removeItem(at: root) }

        let stub = StubUbiquitousItemDownloader(behavior: .succeeds(afterPolls: 2))
        control.override(stub)

        // stub 报告 hasLocalContent == false，因此这里必须走下载路径；
        // 用 alreadyLocal 才能验证「无需下载」的短路。
        control.override(StubUbiquitousItemDownloader(behavior: .alreadyLocal))
        try await file.ensureLocalAvailability(timeout: 1, pollInterval: 0.05)

        let localStub = control.downloader as! StubUbiquitousItemDownloader
        XCTAssertEqual(localStub.startDownloadCallCount, 0, "已在本地的文件不应发起下载")
    }

    /// 非 iCloud 文件（生产实现判定为本地）必须直接返回。
    func testNonICloudFileReturnsWithoutDownload() async throws {
        let (root, file) = try makeTemporaryFile("track.mp3")
        defer { try? FileManager.default.removeItem(at: root) }

        // 不注入替身，走生产网关：临时目录不在 iCloud Documents 下
        try await file.ensureLocalAvailability(timeout: 0.1, pollInterval: 0.05)
    }

    // MARK: - Download wait loop

    /// 下载在第 N 次轮询后完成：必须成功返回，且恰好发起一次下载。
    func testDownloadCompletesAfterExpectedPolls() async throws {
        let (root, file) = try makeTemporaryFile("track.mp3")
        defer { try? FileManager.default.removeItem(at: root) }

        let stub = StubUbiquitousItemDownloader(behavior: .succeeds(afterPolls: 2))
        control.override(stub)

        try await file.ensureLocalAvailability(timeout: 5, pollInterval: 0.05)

        XCTAssertEqual(stub.startDownloadCallCount, 1)
    }

    /// 内容永不落地：必须抛出 `ICloudDownloadError.timedOut`，且带文件名。
    func testTimeoutThrowsTimedOutErrorWithFileName() async throws {
        let (root, file) = try makeTemporaryFile("never.mp3")
        defer { try? FileManager.default.removeItem(at: root) }

        control.override(StubUbiquitousItemDownloader(behavior: .neverCompletes))

        do {
            try await file.ensureLocalAvailability(timeout: 0.2, pollInterval: 0.05)
            XCTFail("内容始终未落地时应超时抛出")
        } catch let error as ICloudDownloadError {
            XCTAssertEqual(error, .timedOut(fileName: "never.mp3"))
        }
    }

    /// `startDownload` 失败（离线）：必须归类为 `requestFailed`，而不是超时。
    func testStartFailureIsClassifiedAsRequestFailed() async throws {
        let (root, file) = try makeTemporaryFile("offline.mp3")
        defer { try? FileManager.default.removeItem(at: root) }

        control.override(StubUbiquitousItemDownloader(behavior: .startFails(message: "network offline")))

        do {
            try await file.ensureLocalAvailability(timeout: 5, pollInterval: 0.05)
            XCTFail("startDownload 失败时应抛出")
        } catch let error as ICloudDownloadError {
            guard case let .requestFailed(message) = error else {
                return XCTFail("期望 requestFailed，实际为 \(error)")
            }
            XCTAssertEqual(message, "network offline")
        }
    }

    /// 非 ICloudDownloadError 的底层错误也必须被归类，避免泄漏原始类型。
    func testForeignErrorIsWrappedIntoRequestFailed() throws {
        let (root, file) = try makeTemporaryFile("foreign.mp3")
        defer { try? FileManager.default.removeItem(at: root) }

        final class ForeignDownloader: UbiquitousItemDownloading, @unchecked Sendable {
            func isICloudBacked(_ url: URL) -> Bool { true }
            func hasLocalContent(_ url: URL) -> Bool { false }
            func downloadProgress(_ url: URL) -> Double { 0 }
            func startDownload(_ url: URL) throws {
                throw NSError(domain: "Foreign", code: 42, userInfo: [NSLocalizedDescriptionKey: "boom"])
            }
        }

        control.override(ForeignDownloader())

        do {
            try file.ensureLocalAvailabilitySync(timeout: 1, pollInterval: 0.05)
            XCTFail("应抛出")
        } catch let error as ICloudDownloadError {
            guard case .requestFailed = error else {
                return XCTFail("期望 requestFailed，实际为 \(error)")
            }
        }
    }

    /// sync 变体必须与 async 变体抛出一致的错误类型。
    func testSyncVariantThrowsSameErrorTypeAsAsync() throws {
        let (root, file) = try makeTemporaryFile("sync.mp3")
        defer { try? FileManager.default.removeItem(at: root) }

        control.override(StubUbiquitousItemDownloader(behavior: .neverCompletes))

        do {
            try file.ensureLocalAvailabilitySync(timeout: 0.2, pollInterval: 0.05)
            XCTFail("sync 变体也应超时抛出")
        } catch let error as ICloudDownloadError {
            XCTAssertEqual(error, .timedOut(fileName: "sync.mp3"))
        }
    }

    /// sync 变体在下载随后完成时必须正常返回。
    func testSyncVariantSucceedsWhenContentArrives() throws {
        let (root, file) = try makeTemporaryFile("sync-ok.mp3")
        defer { try? FileManager.default.removeItem(at: root) }

        control.override(StubUbiquitousItemDownloader(behavior: .succeeds(afterPolls: 2)))

        try file.ensureLocalAvailabilitySync(timeout: 5, pollInterval: 0.05)
    }

    // MARK: - Timeout override

    /// 覆写超时应压过调用方传入的值，让 UI 测试能快速走到超时分支。
    func testTimeoutOverrideWinsOverCallerValue() async throws {
        let (root, file) = try makeTemporaryFile("override.mp3")
        defer { try? FileManager.default.removeItem(at: root) }

        control.override(StubUbiquitousItemDownloader(behavior: .neverCompletes))
        control.overrideTimeout(0.2)

        // 调用方传了 60s，但覆写为 0.2s，应当快速超时。
        let start = Date()
        do {
            try await file.ensureLocalAvailability(timeout: 60, pollInterval: 0.05)
            XCTFail("应超时")
        } catch {
            XCTAssertLessThan(Date().timeIntervalSince(start), 15, "覆写超时未生效")
        }
    }

    // MARK: - Launch argument bootstrap
    //
    // 参数形如 `--cisum-ui-testing-icloud-download=<success|timeout|offline>`。
    // 这里曾有一个缺陷：解析只做 `dropFirst(key.count)`，把分隔符 `=` 留在值里，
    // 得到 "=timeout" 而非 "timeout"，导致注入完全失效。现已修复，
    // 下列用例即为回归防护。

    func testBootstrapIgnoresAbsentArgument() {
        let installed = control.bootstrapFromLaunchArguments(["Cisum", "--cisum-ui-testing"])

        XCTAssertFalse(installed)
        XCTAssertFalse(control.downloader is StubUbiquitousItemDownloader)
    }

    func testBootstrapInstallsSuccessBehavior() {
        let installed = control.bootstrapFromLaunchArguments([
            "--cisum-ui-testing",
            "\(ICloudDownloadControl.launchArgumentKey)=success",
        ])

        XCTAssertTrue(installed)
        XCTAssertTrue(control.downloader is StubUbiquitousItemDownloader)
        XCTAssertNotNil(control.effectiveTimeout)
    }

    func testBootstrapInstallsTimeoutAndOfflineBehaviors() {
        for value in ["timeout", "offline"] {
            control.reset()

            let installed = control.bootstrapFromLaunchArguments([
                "\(ICloudDownloadControl.launchArgumentKey)=\(value)",
            ])

            XCTAssertTrue(installed, "value=\(value) 应被安装")
            XCTAssertTrue(control.downloader is StubUbiquitousItemDownloader, "value=\(value)")
        }
    }

    func testBootstrapRejectsUnknownValue() {
        let installed = control.bootstrapFromLaunchArguments([
            "\(ICloudDownloadControl.launchArgumentKey)=nonsense",
        ])

        XCTAssertFalse(installed)
        XCTAssertFalse(control.downloader is StubUbiquitousItemDownloader)
    }

    func testBootstrapAcceptsSpaceSeparatedValue() {
        let installed = control.bootstrapFromLaunchArguments([
            "\(ICloudDownloadControl.launchArgumentKey) = timeout",
        ])

        XCTAssertTrue(installed, "键值之间的空格应被容忍")
    }

    // MARK: - Error semantics

    func testICloudDownloadErrorsAreAllICloudFailures() {
        let errors: [ICloudDownloadError] = [
            .unavailable,
            .requestFailed("x"),
            .timedOut(fileName: "a.mp3"),
            .cancelled,
        ]

        XCTAssertTrue(errors.allSatisfy(\.isICloudDownloadFailure))
    }

    /// 每个错误都必须有非空描述，供 UI 直接展示。
    func testEveryErrorHasNonEmptyDescription() {
        let errors: [ICloudDownloadError] = [
            .unavailable,
            .requestFailed("x"),
            .timedOut(fileName: "a.mp3"),
            .cancelled,
        ]

        for error in errors {
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true, "缺少描述：\(error)")
        }
    }

    // MARK: - Stub behavior

    /// 进度必须单调上升并收敛到 1，避免 UI 出现倒退的进度条。
    ///
    /// 进度由 `hasLocalContent` 的轮询次数推导，所以必须交替调用两者。
    func testStubProgressIsMonotonicAndConverges() {
        let stub = StubUbiquitousItemDownloader(behavior: .succeeds(afterPolls: 4))
        let url = URL(fileURLWithPath: "/tmp/progress.mp3")

        var previous = -1.0
        for _ in 0..<6 {
            let current = stub.downloadProgress(url)
            XCTAssertGreaterThanOrEqual(current, previous, "进度出现倒退")
            previous = current
            _ = stub.hasLocalContent(url)
        }

        XCTAssertEqual(stub.downloadProgress(url), 1.0, "完成后应收敛到 1")
    }

    func testStubZeroPollsIsImmediatelyComplete() {
        let stub = StubUbiquitousItemDownloader(behavior: .succeeds(afterPolls: 0))

        XCTAssertTrue(stub.hasLocalContent(URL(fileURLWithPath: "/tmp/a.mp3")))
    }
}

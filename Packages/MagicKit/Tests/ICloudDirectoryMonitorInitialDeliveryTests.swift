import Foundation
import Testing
import Combine

@testable import MagicKit

/// `ICloudDirectoryMonitor` 的首次扫描交付回归。
///
/// ## 背景
///
/// 有声书场景长期显示「正在读取有声书仓库」，对应的根因是
/// `BookRepo.waitForInitialSync()` 一直没返回 —— 它在等目录监控器的
/// **首次扫描回调**。
///
/// `LocalDirectoryMonitor.start()` 在 macOS 上**同步**调用 `performInitialScan()`，
/// 失败时也会回调（带 error），因此等待者一定会被唤醒。
///
/// `ICloudDirectoryMonitor.start()` 则把首次扫描放到后台队列异步执行，
/// 并且用 `[weak self]` 捕获自己。两处都可能让 `onChange` **永远不被调用**：
///
/// 1. `deliverInitialScan()` 的 `guard let self else { return }`：
///    监控器若在扫描完成前被释放，首次回调直接丢失，等待者永久挂起；
/// 2. 扫描失败时虽然会回调，但必须确认回调**确实发生**且带 error，
///    否则调用方无法区分「空仓库」与「扫描失败」。
///
/// 因此这里钉住的核心契约是：
/// **`start()` 之后，调用方一定会收到至少一次 `onChange` 回调**
/// （哪怕是空结果 + error）。只要这条成立，`waitForInitialSync()`
/// 就不可能永久挂起。
@Suite("ICloudDirectoryMonitor 首次扫描交付")
struct ICloudDirectoryMonitorInitialDeliveryTests {

    /// 监控器启动后必须回调一次 `onChange`。
    ///
    /// 目录不存在时会走「扫描失败」分支：回调必须发生，且带 error。
    @Test("目录不存在时仍回调 onChange（否则首次同步等待者永久挂起）")
    func startAlwaysDeliversInitialCallbackOnMissingDirectory() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("cisum-icloud-missing-\(UUID().uuidString)", isDirectory: true)

        let box = InitialCallbackBox()

        let monitor = ICloudDirectoryMonitor(
            directoryURL: missing,
            verbose: false,
            caller: "ICloudDirectoryMonitorInitialDeliveryTests",
            onProgress: { _, _ in },
            onDeleted: { _ in }
        ) { items, isFirst, error in
            box.record(items: items, isFirst: isFirst, error: error)
        }

        let cancellable = monitor.start()
        defer { cancellable.cancel() }

        #expect(await box.waitForFirstCallback(), "start() 之后必须回调一次 onChange")
        #expect(box.error != nil, "目录不存在时必须带 error 回调，而不是静默")
        #expect(box.items?.isEmpty == true)
    }

    /// 目录存在时必须回调一次，并且不带 error。
    @Test("目录存在时回调一次且无 error")
    func startDeliversInitialCallbackForExistingDirectory() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cisum-icloud-ok-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let box = InitialCallbackBox()

        let monitor = ICloudDirectoryMonitor(
            directoryURL: root,
            verbose: false,
            caller: "ICloudDirectoryMonitorInitialDeliveryTests",
            onProgress: { _, _ in },
            onDeleted: { _ in }
        ) { items, isFirst, error in
            box.record(items: items, isFirst: isFirst, error: error)
        }

        let cancellable = monitor.start()
        defer { cancellable.cancel() }

        #expect(await box.waitForFirstCallback(), "start() 之后必须回调一次 onChange")
        #expect(box.isFirst == true, "首次回调必须标记 isFirst")
        #expect(box.error == nil, "目录可读时不应带 error")
        #expect(box.items?.isEmpty == true)
    }
}

/// 跨线程记录首次回调结果（回调发生在后台队列）。
private final class InitialCallbackBox: @unchecked Sendable {
    private let lock = NSLock()
    private var didReceiveFirst = false

    var error: Error?
    var items: [URL]?
    var isFirst: Bool?

    func record(items: [URL], isFirst: Bool, error: Error?) {
        lock.lock()
        defer { lock.unlock() }
        guard !didReceiveFirst else { return }
        didReceiveFirst = true
        self.items = items
        self.isFirst = isFirst
        self.error = error
    }

    /// 轮询等待首次回调到达。
    func waitForFirstCallback(timeout: TimeInterval = 10) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            lock.lock()
            let received = didReceiveFirst
            lock.unlock()
            if received { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        lock.lock()
        defer { lock.unlock() }
        return didReceiveFirst
    }
}

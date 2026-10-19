import Combine
import Foundation
import Testing
@testable import MagicKit

// MARK: - 头像下载监控的引用计数

/// 同一 URL 多次订阅只应创建一个监听器，引用计数递增。
///
/// 这是监控器的核心契约：多个头像视图同时展示同一文件时，
/// 若每次订阅都新建监听器，会重复发起下载请求。
@Test func subscribingTwiceToSameURLKeepsOneMonitor() async {
    let monitor = AvatarDownloadMonitor()
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("avatar-monitor-\(UUID().uuidString).png")

    _ = await monitor.subscribe(url: url, verbose: false)
    let countAfterFirst = await MainActor.run { monitor.activeMonitorCount }
    _ = await monitor.subscribe(url: url, verbose: false)
    let countAfterSecond = await MainActor.run { monitor.activeMonitorCount }

    await monitor.unsubscribe(url: url, verbose: false)
    await monitor.unsubscribe(url: url, verbose: false)

    #expect(countAfterFirst == 1)
    // 同一 URL 不应新增监听器
    #expect(countAfterSecond == 1)
}

/// 引用计数归零后应清理监听器。
@Test func unsubscribeRemovesMonitorWhenLastSubscriberLeaves() async {
    let monitor = AvatarDownloadMonitor()
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("avatar-cleanup-\(UUID().uuidString).png")

    _ = await monitor.subscribe(url: url, verbose: false)
    await monitor.unsubscribe(url: url, verbose: false)

    let count = await MainActor.run { monitor.activeMonitorCount }
    #expect(count == 0)
}

/// 取消未订阅的 URL 必须静默忽略 —— 视图重复消失时会走到这里，
/// 抛错或崩溃都不合适。
@Test func unsubscribingUnknownURLIsIgnored() async {
    let monitor = AvatarDownloadMonitor()
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("avatar-unknown-\(UUID().uuidString).png")

    await monitor.unsubscribe(url: url, verbose: false)
    let count = await MainActor.run { monitor.activeMonitorCount }
    #expect(count == 0)
}

/// 多次取消同一 URL 不应把计数压到负数或影响其它监听器。
@Test func repeatedUnsubscribeDoesNotCorruptCount() async {
    let monitor = AvatarDownloadMonitor()
    let base = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("avatar-multi-\(UUID().uuidString)")
    let first = base.appendingPathComponent("a.png")
    let second = base.appendingPathComponent("b.png")

    _ = await monitor.subscribe(url: first, verbose: false)
    _ = await monitor.subscribe(url: second, verbose: false)
    #expect(await MainActor.run { monitor.activeMonitorCount } == 2)

    // 第一个退订后，第二个应仍然存活
    await monitor.unsubscribe(url: first, verbose: false)
    #expect(await MainActor.run { monitor.activeMonitorCount } == 1)

    // 对已退订的 URL 重复退订不应影响剩余的那个
    await monitor.unsubscribe(url: first, verbose: false)
    #expect(await MainActor.run { monitor.activeMonitorCount } == 1)

    await monitor.unsubscribe(url: second, verbose: false)
    #expect(await MainActor.run { monitor.activeMonitorCount } == 0)
}

/// 三次订阅需要三次退订才真正清理 —— 引用计数不能提前归零，
/// 否则一个视图退出就会中断其他视图的进度回调。
@Test func referenceCountRequiresMatchingUnsubscribeCount() async {
    let monitor = AvatarDownloadMonitor()
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("avatar-refcount-\(UUID().uuidString).png")

    _ = await monitor.subscribe(url: url, verbose: false)
    _ = await monitor.subscribe(url: url, verbose: false)
    _ = await monitor.subscribe(url: url, verbose: false)

    await monitor.unsubscribe(url: url, verbose: false)
    await monitor.unsubscribe(url: url, verbose: false)
    // 还有一个订阅者，监听器必须仍在
    #expect(await MainActor.run { monitor.activeMonitorCount } == 1)

    await monitor.unsubscribe(url: url, verbose: false)
    #expect(await MainActor.run { monitor.activeMonitorCount } == 0)
}

/// 订阅应返回可用发布者，且发出的进度值在 0...1 区间内。
@Test func subscriptionEmitsBoundedProgress() async {
    let monitor = AvatarDownloadMonitor()
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("avatar-publisher-\(UUID().uuidString).png")

    let publisher = await monitor.subscribe(url: url, verbose: false)

    // AnyPublisher 不暴露 currentValue，订阅后读首个值即可验证量程。
    var received: Double?
    let token = publisher.prefix(1).sink(
        receiveCompletion: { _ in },
        receiveValue: { received = $0 }
    )
    try? await Task.sleep(for: .milliseconds(30))

    await monitor.unsubscribe(url: url, verbose: false)
    _ = token

    let value = try? #require(received)
    if let value {
        #expect(value >= 0)
        #expect(value <= 1)
    }
}

import Foundation
import Testing
@testable import KitAppEvents

/// 内核事件的通知名与订阅便捷方法。
///
/// 三条不变式：
/// 1. `Notification.Name` 上的静态常量必须与对应事件的 `notificationName` 同源——
///    生产者与订阅者只要有一侧写错 raw value，事件就静默丢失；
/// 2. `onCisumXXX` 订阅便捷方法必须真的把回调送达；
/// 3. 事件枚举的所有 case 都必须能通过 `Notification.Name` 表达。
@Suite @MainActor struct CisumKernelEventNotificationTests {
    private let manager = EventManager()

    private func observe(
        _ name: Notification.Name,
        _ onNote: @escaping (Notification) -> Void
    ) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: nil
        ) { note in
            onNote(note)
        }
    }

    /// 等待条件成立。
    ///
    /// 这几个订阅便捷方法把回调投递到 **主 OperationQueue**，与测试协程不在
    /// 同一条执行路径上，投递时刻不确定——固定 sleep 会在负载高时偶发失败。
    /// 这里改为轮询，直到条件成立或超时。
    private func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: @MainActor () -> Bool
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        return condition()
    }

    /// 每个事件的静态通知名常量必须与枚举自身的 raw value 一致。
    @Test func notificationNameConstantsMatchTheirEvents() {
        #expect(Notification.Name.cisumThemeDidChange
            == CisumKernelEvent.themeDidChange.notificationName)
        #expect(Notification.Name.cisumPlaybackStateDidChange
            == CisumKernelEvent.playbackStateDidChange.notificationName)
        #expect(Notification.Name.cisumPlaybackProgressDidUpdate
            == CisumKernelEvent.playbackProgressDidUpdate.notificationName)
        #expect(Notification.Name.cisumPlaybackAssetDidChange
            == CisumKernelEvent.playbackAssetDidChange.notificationName)
        #expect(Notification.Name.cisumCloudStatusDidChange
            == CisumKernelEvent.cloudStatusDidChange.notificationName)
        #expect(Notification.Name.cisumGuideDidComplete
            == CisumKernelEvent.guideDidComplete.notificationName)
        #expect(Notification.Name.cisumAppLifecycleDidChange
            == CisumKernelEvent.appLifecycleDidChange.notificationName)
        #expect(Notification.Name.cisumAudioDBSynced
            == CisumKernelEvent.audioDBSynced.notificationName)
        #expect(Notification.Name.cisumAudioDBUpdated
            == CisumKernelEvent.audioDBUpdated.notificationName)
    }

    /// 事件枚举的每个 case 都必须有对应的通知名常量可用。
    @Test func everyEventHasAStableNotificationName() {
        for event in CisumKernelEvent.allCases {
            #expect(event.notificationName.rawValue == event.rawValue)
        }
    }

    /// `onCisumThemeDidChange` 订阅后必须收到主题变更事件。
    @Test func themeSubscriptionReceivesPostedEvent() async throws {
        var count = 0
        let token = NotificationCenter.default.onCisumThemeDidChange { count += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.postThemeDidChange()
        let delivered = try await waitUntil { count == 1 }

        #expect(delivered)
    }

    /// `onCisumPlaybackStateDidChange` 订阅后必须收到播放状态变更事件。
    @Test func playbackStateSubscriptionReceivesPostedEvent() async throws {
        var count = 0
        let token = NotificationCenter.default.onCisumPlaybackStateDidChange { count += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.postPlaybackStateDidChange(isPlaying: true)
        let delivered = try await waitUntil { count == 1 }

        #expect(delivered)
    }

    /// `onCisumCloudStatusDidChange` 订阅后必须收到 iCloud 状态变更事件。
    @Test func cloudStatusSubscriptionReceivesPostedEvent() async throws {
        var count = 0
        let token = NotificationCenter.default.onCisumCloudStatusDidChange { count += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.postCloudStatusDidChange()
        let delivered = try await waitUntil { count == 1 }

        #expect(delivered)
    }

    /// 取消订阅后不再收到事件。
    @Test func cancelledSubscriptionStopsReceivingEvents() async throws {
        var count = 0
        let token = NotificationCenter.default.onCisumThemeDidChange { count += 1 }

        manager.postThemeDidChange()
        let delivered = try await waitUntil { count == 1 }
        #expect(delivered)

        NotificationCenter.default.removeObserver(token)
        manager.postThemeDidChange()
        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(count == 1)
    }

    /// 资源变更事件：有标题时携带标题载荷。
    @Test func playbackAssetChangeCarriesTitlePayload() {
        var title: String?
        let token = observe(.cisumPlaybackAssetDidChange) { note in
            title = note.userInfo?["title"] as? String
        }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.postPlaybackAssetDidChange(title: "夜曲")

        #expect(title == "夜曲")
    }

    /// 资源变更事件：不带标题时不产生 `title` 载荷。
    @Test func playbackAssetChangeWithoutTitleCarriesNoPayload() {
        var userInfo: [AnyHashable: Any]?
        var delivered = false
        let token = observe(.cisumPlaybackAssetDidChange) { note in
            delivered = true
            userInfo = note.userInfo
        }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.postPlaybackAssetDidChange()

        #expect(delivered)
        #expect(userInfo == nil)
    }

    /// 播放状态事件：不带 `isPlaying` 时不产生载荷。
    @Test func playbackStateChangeWithoutFlagCarriesNoPayload() {
        var userInfo: [AnyHashable: Any]?
        let token = observe(.cisumPlaybackStateDidChange) { note in
            userInfo = note.userInfo
        }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.postPlaybackStateDidChange()

        #expect(userInfo == nil)
    }

    /// 引导完成 / 音频库同步 / 音频库更新三个便捷方法必须投递到各自的通知名上。
    @Test func remainingConvenienceSendersUseTheirOwnNotificationNames() {
        var guideDelivered = false
        var syncedDelivered = false
        var updatedDelivered = false

        let guideToken = observe(.cisumGuideDidComplete) { _ in guideDelivered = true }
        let syncedToken = observe(.cisumAudioDBSynced) { _ in syncedDelivered = true }
        let updatedToken = observe(.cisumAudioDBUpdated) { _ in updatedDelivered = true }
        defer {
            NotificationCenter.default.removeObserver(guideToken)
            NotificationCenter.default.removeObserver(syncedToken)
            NotificationCenter.default.removeObserver(updatedToken)
        }

        manager.postGuideDidComplete()
        manager.postAudioDBSynced()
        manager.postAudioDBUpdated()

        #expect(guideDelivered)
        #expect(syncedDelivered)
        #expect(updatedDelivered)
    }

    /// 开启 verbose 后事件仍必须照常投递（只多一行日志）。
    ///
    /// 顺带覆盖日志里的发送者类型插值——带 object 才能算出 `type(of:)`。
    @Test func verboseLoggingKeepsDeliveryIntact() {
        let previous = EventManager.verbose
        EventManager.verbose = true
        defer { EventManager.verbose = previous }

        var delivered = false
        let token = observe(.cisumThemeDidChange) { _ in delivered = true }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.postThemeDidChange(object: "sender")

        #expect(delivered)
    }
}

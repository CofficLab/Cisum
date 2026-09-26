import Foundation
import Testing
@testable import CisumKernelSupport

/// 内核事件分发器的确定性回归：`EventManager` 必须把事件广播到
/// `NotificationCenter`，且便捷方法要携带正确的通知名与 userInfo 载荷。
@Suite @MainActor struct EventManagerTests {
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

    @Test func postDeliversNotificationWithPayload() {
        let event = CisumKernelEvent.storageLocationDidChange
        var delivered = false
        var payload: [AnyHashable: Any]?
        let token = observe(event.notificationName) { note in
            delivered = true
            payload = note.userInfo
        }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.post(event, userInfo: ["path": "/tmp"])

        #expect(delivered)
        #expect(payload?["path"] as? String == "/tmp")
    }

    @Test func postThemeDidChangeUsesStableNotificationName() {
        var delivered = false
        let token = observe(.cisumThemeDidChange) { _ in delivered = true }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.postThemeDidChange()

        #expect(delivered)
    }

    @Test func postPlaybackStateDidChangeCarriesIsPlayingPayload() {
        var isPlaying: Bool?
        let token = observe(.cisumPlaybackStateDidChange) { note in
            isPlaying = note.userInfo?["isPlaying"] as? Bool
        }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.postPlaybackStateDidChange(isPlaying: true)

        #expect(isPlaying == true)
    }

    @Test func postPlaybackProgressDidUpdateCarriesNumericPayload() {
        var progress: Double?
        var currentTime: TimeInterval?
        let token = observe(.cisumPlaybackProgressDidUpdate) { note in
            progress = note.userInfo?["progress"] as? Double
            currentTime = note.userInfo?["currentTime"] as? TimeInterval
        }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.postPlaybackProgressDidUpdate(progress: 0.5, currentTime: 12.25)

        #expect(progress == 0.5)
        #expect(currentTime == 12.25)
    }

    @Test func postAppLifecycleDidChangeCarriesPhasePayload() {
        var phase: String?
        let token = observe(.cisumAppLifecycleDidChange) { note in
            phase = note.userInfo?["phase"] as? String
        }
        defer { NotificationCenter.default.removeObserver(token) }

        manager.postAppLifecycleDidChange(phase: "ready")

        #expect(phase == "ready")
    }

    @Test func allEventRawValuesAreStable() {
        #expect(CisumKernelEvent.themeDidChange.rawValue == "com.coffic.cisum.themeDidChange")
        #expect(CisumKernelEvent.storageLocationDidChange.rawValue == "com.coffic.cisum.storageLocationDidChange")
        #expect(CisumKernelEvent.storageLocationDidReset.rawValue == "com.coffic.cisum.storageLocationDidReset")
        #expect(CisumKernelEvent.enabledPluginsDidChange.rawValue == "com.coffic.cisum.enabledPluginsDidChange")
        #expect(CisumKernelEvent.playbackStateDidChange.rawValue == "com.coffic.cisum.playbackStateDidChange")
        #expect(CisumKernelEvent.playbackProgressDidUpdate.rawValue == "com.coffic.cisum.playbackProgressDidUpdate")
        #expect(CisumKernelEvent.playbackAssetDidChange.rawValue == "com.coffic.cisum.playbackAssetDidChange")
        #expect(CisumKernelEvent.cloudStatusDidChange.rawValue == "com.coffic.cisum.cloudStatusDidChange")
        #expect(CisumKernelEvent.guideDidComplete.rawValue == "com.coffic.cisum.guideDidComplete")
        #expect(CisumKernelEvent.appLifecycleDidChange.rawValue == "com.coffic.cisum.appLifecycleDidChange")
        #expect(CisumKernelEvent.audioDBSynced.rawValue == "com.coffic.cisum.audioDBSynced")
        #expect(CisumKernelEvent.audioDBUpdated.rawValue == "com.coffic.cisum.audioDBUpdated")
        #expect(CisumKernelEvent.sceneDidChange.rawValue == "com.coffic.cisum.sceneDidChange")
    }

    @Test func notificationNameMatchesRawValue() {
        for event in CisumKernelEvent.allCases {
            #expect(event.notificationName == Notification.Name(event.rawValue))
        }
    }
}

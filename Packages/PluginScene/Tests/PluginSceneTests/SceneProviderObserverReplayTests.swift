import Foundation
import ProviderScene
import Testing
@testable import PluginScene

/// 场景 Provider 的「订阅即重放」契约。
///
/// ## 为什么需要重放
///
/// 场景恢复发生在 `ScenePlugin.onReady`，而消费方（如 `PluginAudioDBView`，
/// `order` 更小）的 `onReady` 更早跑完——它们订阅时 `currentScene` 还是 `nil`，
/// 场景是在它们订阅**之后**才恢复的。若 Provider 只在场景**变化**时派发事件，
/// 那些消费方就永远等不到通知，音乐库内容区会一直是空的。
///
/// 因此契约是：**订阅即刻收到一次当前场景**（若已有）。
@Suite("场景 Provider 的订阅重放")
@MainActor
struct SceneProviderObserverReplayTests {
    @Test("尚无场景时订阅不派发事件")
    func noReplayWhenSceneIsNil() {
        let provider = SceneProvider()

        var received: [AppScene?] = []
        let handle = provider.addObserver { event in
            if case let .selectionChanged(scene) = event {
                received.append(scene)
            }
        }

        #expect(received.isEmpty, "还没有场景时不应派发事件")
        handle.cancel()
    }

    @Test("已有场景时订阅立即收到当前场景")
    func replaysCurrentSceneOnSubscribe() {
        let provider = SceneProvider()
        provider.restoreCurrentScene()
        #expect(provider.currentScene == .music)

        var received: [AppScene?] = []
        let handle = provider.addObserver { event in
            if case let .selectionChanged(scene) = event {
                received.append(scene)
            }
        }

        #expect(received.count == 1, "订阅时应立即收到一次当前场景")
        #expect(received.first == .music)
        handle.cancel()
    }

    @Test("订阅后发生场景切换仍会派发事件")
    func stillReceivesLaterChanges() {
        let provider = SceneProvider()
        provider.restoreCurrentScene()

        var received: [AppScene?] = []
        let handle = provider.addObserver { event in
            if case let .selectionChanged(scene) = event {
                received.append(scene)
            }
        }

        provider.setCurrentScene(.audiobooks)

        #expect(received.count == 2, "重放之外，切���事件也必须派发")
        #expect(received.first == .music)
        #expect(received.last == .audiobooks)
        handle.cancel()
    }

    @Test("订阅晚于场景恢复时也能拿到正确场景")
    func lateSubscriberGetsRestoredScene() {
        // 复现真实缺陷：场景先恢复，订阅后发生。
        let provider = SceneProvider()
        provider.restoreCurrentScene()

        // 消费方此刻才建立能力并订阅。
        var received: [AppScene?] = []
        let handle = provider.addObserver { event in
            if case let .selectionChanged(scene) = event {
                received.append(scene)
            }
        }

        #expect(received.first == .music, "晚订阅者必须拿到已恢复的场景，否则内容区一直是空的")
        handle.cancel()
    }

    @Test("取消订阅后不再收到事件")
    func cancelStopsDelivery() {
        let provider = SceneProvider()
        provider.restoreCurrentScene()

        var count = 0
        let handle = provider.addObserver { _ in count += 1 }
        #expect(count == 1, "订阅即重放一次")

        handle.cancel()
        provider.setCurrentScene(.audiobooks)
        #expect(count == 1, "取消订阅后不应再收到事件")
    }
}

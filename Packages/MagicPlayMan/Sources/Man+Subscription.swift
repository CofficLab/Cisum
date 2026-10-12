import Combine
import Foundation
import ProviderPlayback
import OSLog
import SwiftUI
import CisumUIComponents
import LumiUI
import MagicKit

extension MagicPlayMan {
    /// 播放事件发布者
    public class PlaybackEvents: ObservableObject {
        /// 导航请求的方向。
        public enum NavigationDirection {
            case previous
            case next
        }

        /// 播放器无法发出上一首/下一首请求时的诊断信息。
        public struct NavigationFailure {
            public let direction: NavigationDirection
            public let reason: String

            public init(direction: NavigationDirection, reason: String) {
                self.direction = direction
                self.reason = reason
            }
        }

        /// 事件订阅者信息
        public struct Subscriber {
            let id: UUID
            let name: String
            let date: Date
            let hasNavigationHandler: Bool

            public init(
                name: String,
                hasNavigationHandler: Bool = false
            ) {
                self.id = UUID()
                self.name = name
                self.date = Date()
                self.hasNavigationHandler = hasNavigationHandler
            }
        }

        @Published private(set) var subscribers: [Subscriber] = []

        public let onTrackFinished = PassthroughSubject<URL, Never>()
        public let onPlaybackFailed = PassthroughSubject<PlaybackState.PlaybackError, Never>()
        public let onBufferingStateChanged = PassthroughSubject<Bool, Never>()
        public let onStateChanged = PassthroughSubject<PlaybackState, Never>()
        public let onPreviousRequested = PassthroughSubject<URL, Never>()
        public let onNextRequested = PassthroughSubject<URL, Never>()
        public let onNavigationFailed = PassthroughSubject<NavigationFailure, Never>()
        public let onLikeStatusChanged = PassthroughSubject<(asset: URL, isLiked: Bool), Never>()
        public let onPlayModeChanged = PassthroughSubject<PlaybackMode, Never>()
        public let onCurrentURLChanged = PassthroughSubject<URL?, Never>()

        func addSubscriber(
            name: String,
            hasNavigationHandler: Bool = false
        ) -> UUID {
            let subscriber = Subscriber(
                name: name,
                hasNavigationHandler: hasNavigationHandler
            )
            subscribers.append(subscriber)
            return subscriber.id
        }

        /// 注册一个接收上一首/下一首请求的外部导航处理器。
        ///
        /// 公开专用入口，供 `ProviderPlayback` 这类桥接层维护导航订阅状态；
        /// 其他订阅者仍通过 `subscribe(...)` 注册，避免暴露内部订阅实现。
        @discardableResult
        public func addNavigationSubscriber(name: String) -> UUID {
            addSubscriber(name: name, hasNavigationHandler: true)
        }

        func removeSubscriber(id: UUID) {
            subscribers.removeAll { $0.id == id }
        }

        /// 撤销由 `addNavigationSubscriber(name:)` 返回的订阅。
        public func removeNavigationSubscriber(id: UUID) {
            removeSubscriber(id: id)
        }

        func getSubscriberInfo(id: UUID) -> Subscriber? {
            subscribers.first { $0.id == id }
        }

        var hasNavigationSubscribers: Bool {
            subscribers.contains { $0.hasNavigationHandler }
        }

        init() {}
    }

    @discardableResult
    public func subscribe(
        name: String,
        onTrackFinished: ((URL) -> Void)? = nil,
        onPlaybackFailed: ((PlaybackState.PlaybackError) -> Void)? = nil,
        onBufferingStateChanged: ((Bool) -> Void)? = nil,
        onStateChanged: ((PlaybackState) -> Void)? = nil,
        onPreviousRequested: ((URL) -> Void)? = nil,
        onNextRequested: ((URL) -> Void)? = nil,
        onLikeStatusChanged: ((URL, Bool) -> Void)? = nil,
        onPlayModeChanged: ((PlaybackMode) -> Void)? = nil,
        onCurrentURLChanged: ((URL?) -> Void)? = nil
    ) -> UUID {
        let hasNavigationHandler = onPreviousRequested != nil || onNextRequested != nil
        let subscriberId = events.addSubscriber(
            name: name,
            hasNavigationHandler: hasNavigationHandler
        )
        var subscriberCancellables = Set<AnyCancellable>()

        if let handler = onTrackFinished {
            events.onTrackFinished
                .receive(on: DispatchQueue.main)
                .sink { [weak self] asset in
                    if self?.verbose == true {
                        os_log("\(self?.t ?? "")Event: single track completed - handled by \(name)")
                    }
                    handler(asset)
                }
                .store(in: &subscriberCancellables)
        }

        if let handler = onPlaybackFailed {
            events.onPlaybackFailed
                .receive(on: DispatchQueue.main)
                .sink { [weak self] error in
                    if self?.verbose == true {
                        os_log("\(self?.t ?? "")Event: playback failed - handled by \(name)")
                    }
                    handler(error)
                }
                .store(in: &subscriberCancellables)
        }

        if let handler = onBufferingStateChanged {
            events.onBufferingStateChanged
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isBuffering in
                    if self?.verbose == true {
                        os_log("\(self?.t ?? "")Event: buffering state changed - handled by \(name)")
                    }
                    handler(isBuffering)
                }
                .store(in: &subscriberCancellables)
        }

        if let handler = onStateChanged {
            events.onStateChanged
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    if self?.verbose == true {
                        os_log("\(self?.t ?? "")Event: playback state changed - handled by \(name)")
                    }
                    handler(state)
                }
                .store(in: &subscriberCancellables)
        }

        if let handler = onPreviousRequested {
            events.onPreviousRequested
                .receive(on: DispatchQueue.main)
                .sink { [weak self] asset in
                    if self?.verbose == true {
                        os_log("\(self?.t ?? "")Event: previous track requested - handled by \(name)")
                    }
                    handler(asset)
                }
                .store(in: &subscriberCancellables)
        }

        if let handler = onNextRequested {
            events.onNextRequested
                .receive(on: DispatchQueue.main)
                .sink { [weak self] asset in
                    if self?.verbose == true {
                        os_log("\(self?.t ?? "")🍋 Event: current(\(asset.lastThreeComponents())), next track requested - handled by \(name)")
                    }
                    handler(asset)
                }
                .store(in: &subscriberCancellables)
        }

        if let handler = onLikeStatusChanged {
            events.onLikeStatusChanged
                .receive(on: DispatchQueue.main)
                .sink { [weak self] event in
                    if self?.verbose == true {
                        os_log("\(self?.t ?? "")Event: like state changed - handled by \(name)")
                    }
                    handler(event.asset, event.isLiked)
                }
                .store(in: &subscriberCancellables)
        }

        if let handler = onPlayModeChanged {
            events.onPlayModeChanged
                .receive(on: DispatchQueue.main)
                .sink { [weak self] mode in
                    if self?.verbose == true {
                        os_log("\(self?.t ?? "")Event: playback mode changed - handled by \(name)")
                    }
                    handler(mode)
                }
                .store(in: &subscriberCancellables)
        }

        if let handler = onCurrentURLChanged {
            events.onCurrentURLChanged
                .receive(on: DispatchQueue.main)
                .sink { [weak self] url in
                    if self?.verbose == true {
                        os_log("\(self?.t ?? "")Event: current URL changed - handled by \(name)")
                    }
                    handler(url)
                }
                .store(in: &subscriberCancellables)
        }

        eventCancellables[subscriberId] = subscriberCancellables

        return subscriberId
    }

    public func unsubscribe(_ subscriberId: UUID) {
        if let subscriber = events.getSubscriberInfo(id: subscriberId) {
            eventCancellables[subscriberId]?.forEach { $0.cancel() }
            eventCancellables[subscriberId] = nil
            events.removeSubscriber(id: subscriberId)
            if verbose {
                os_log("\(self.t)Unsubscribed: \(subscriber.name)")
            }
        }
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayMan.getPreviewView()
}

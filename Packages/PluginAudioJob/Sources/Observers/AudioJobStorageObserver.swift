import Combine
import Foundation
import ProviderAudioLibrary
import MagicKit

/// 音频后台任务的存储位置变化观察者（迁移 Phase 4）。
///
/// 订阅存储位置变化通知，触发文件系统监控重启；取代原
/// `AudioJobPlugin.setupStorageLocationObserver()` 中直接使用
/// `AudioJobNotificationObserverHolder.shared.cancellables` 的
/// Combine 订阅。
@MainActor
final class AudioJobStorageObserver: SuperLog {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose = false

    private var cancellables: Set<AnyCancellable> = []
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        for notification in AudioPluginHost.storageLocationDidChangeNotifications {
            NotificationCenter.default.publisher(for: notification)
                .sink { [weak self] _ in
                    self?.onChange()
                }
                .store(in: &cancellables)
        }
    }

    func cancel() {
        cancellables.removeAll()
    }
}

import Foundation
import ProviderStorage
import MagicKit

/// 音频设置的存储位置变化观察者（迁移 Phase 5）。
///
/// 订阅 `StorageProviding` 的存储位置事件，
/// 转发到 `AudioSettingsViewModel`；取代原
/// `AudioSettingsStorageChangeModifier` 的多通知 `.onReceive`。
@MainActor
final class AudioSettingsObserver: SuperLog {
    nonisolated static let emoji = "🔧"
    nonisolated static let verbose = false

    private weak var viewModel: AudioSettingsViewModel?
    private var handle: (any StorageProvidingObserverHandle)?

    init(provider: any StorageProviding, viewModel: AudioSettingsViewModel) {
        self.viewModel = viewModel
        handle = provider.addObserver { [weak self] _ in
            self?.viewModel?.handleStorageLocationChanged()
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}

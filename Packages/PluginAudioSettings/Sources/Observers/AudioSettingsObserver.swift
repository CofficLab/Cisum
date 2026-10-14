import Foundation
import MagicKit

/// 音频设置的存储位置变化观察者（迁移 Phase 5）。
///
/// 订阅存储能力的变化信号，
/// 转发到 `AudioSettingsViewModel`；取代原
/// `AudioSettingsStorageChangeModifier` 的多通知 `.onReceive`。
@MainActor
final class AudioSettingsObserver: SuperLog {
    nonisolated static let emoji = "🔧"
    nonisolated static let verbose = false

    private weak var viewModel: AudioSettingsViewModel?
    private var handle: (any AudioSettingsStorageObserverHandle)?

    init(storage: any AudioSettingsStorageCapability, viewModel: AudioSettingsViewModel) {
        self.viewModel = viewModel
        handle = storage.addObserver { [weak self] _ in
            self?.viewModel?.handleStorageLocationChanged()
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
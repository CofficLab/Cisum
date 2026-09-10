import Foundation
import ProviderAudioLibrary
import MagicKit

/// 音频设置的存储位置变化观察者（迁移 Phase 5）。
///
/// 订阅 `AudioPluginHost.storageLocationDidChangeNotifications`，
/// 转发到 `AudioSettingsViewModel`；取代原
/// `AudioSettingsStorageChangeModifier` 的多通知 `.onReceive`。
@MainActor
final class AudioSettingsObserver: SuperLog {
    nonisolated static let emoji = "🔧"
    nonisolated static let verbose = false

    private weak var viewModel: AudioSettingsViewModel?
    private var tokens: [NSObjectProtocol] = []

    init(viewModel: AudioSettingsViewModel) {
        self.viewModel = viewModel
        for name in AudioPluginHost.storageLocationDidChangeNotifications {
            tokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.viewModel?.handleStorageLocationChanged() }
            })
        }
    }

    func cancel() {
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
        tokens.removeAll()
    }
}

import Foundation
import OSLog
import SwiftData
import MagicKit
import ProviderAudioLibrary

/// 音频容器加载的内部错误（迁移 Phase 2，原位于 `AudioRootView`）。
enum AudioContainerLoadError: Error {
    case message(String)

    static let storageMissingReason = "Storage not found"
}

/// 音频根视图的加载状态容器（迁移 Phase 2）。
///
/// 集中管理音频容器初始化、错误与存储变化信号；由插件入口持有并注入
/// `AudioStorageObserver`，View 只观察本 ViewModel，不再直接订阅存储通知。
@MainActor
final class AudioRootViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = true

    @Published private(set) var error: AudioPluginError?
    @Published private(set) var container: ModelContainer?
    @Published private(set) var isInitializing = true
    /// 存储位置变化信号：Observer 写入，View 通过 `.onChange` 弹全局 toast。
    @Published private(set) var storageLocationDidChangeNotice: UUID?

    private var initGeneration = 0
    private let databaseURL: @MainActor () throws -> URL
    private let hasStorageLocation: @MainActor () -> Bool

    init(
        databaseURL: @escaping @MainActor () throws -> URL,
        hasStorageLocation: @escaping @MainActor () -> Bool
    ) {
        self.databaseURL = databaseURL
        self.hasStorageLocation = hasStorageLocation
    }

    /// 重建容器。代际（generation）保护保证旧任务结果不会覆盖新状态。
    func reloadContainer() {
        initGeneration += 1
        let generation = initGeneration
        isInitializing = true
        container = nil
        error = nil

        guard hasStorageLocation() else {
            isInitializing = false
            error = AudioPluginError.initialization(reason: AudioContainerLoadError.storageMissingReason)
            return
        }

        let requestedDatabaseURL: URL
        do {
            requestedDatabaseURL = try databaseURL()
        } catch {
            isInitializing = false
            self.error = AudioPluginError.initialization(reason: error.localizedDescription)
            return
        }

        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                do {
                    return Result<ModelContainer, AudioContainerLoadError>.success(
                        try AudioConfigRepo.getContainer(databaseURL: requestedDatabaseURL)
                    )
                } catch {
                    return Result<ModelContainer, AudioContainerLoadError>.failure(
                        .message(error.localizedDescription)
                    )
                }
            }.value

            guard generation == self.initGeneration else { return }

            switch result {
            case .success(let container):
                self.container = container
                self.error = nil
            case .failure(.message(let message)):
                os_log(.error, "AudioRootViewModel 初始化失败: \(message)")
                self.container = nil
                self.error = AudioPluginError.initialization(reason: message)
            }
            self.isInitializing = false
        }
    }

    /// 存储位置变化：产生新信号供 View 弹 toast。
    func handleStorageLocationChanged() {
        storageLocationDidChangeNotice = UUID()
    }
}

import Combine
import Foundation
import OSLog
import ProviderBook
import SwiftUI
import MagicKit

/// 书籍根容器的集中状态。
///
/// 数据库容器和仓库完全由数据层 Provider 管理；此 ViewModel 只负责向
/// 根视图报告 Provider 是否可用以及存储位置变化。
@MainActor
final class BookRootViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var error: Error?
    @Published private(set) var isLoading = true
    @Published var storageLocationDidChangeNotice = UUID()

    private let bookProvider: (any BookDatabaseProviding)?
    private var initGeneration = 0

    init(bookProvider: (any BookDatabaseProviding)?) {
        self.bookProvider = bookProvider
    }

    func reloadContainer() {
        initGeneration += 1
        let generation = initGeneration
        isLoading = true
        error = nil
        if Self.verbose { os_log("\(self.t)🔄 reloadProvider #\(generation)") }

        Task { @MainActor in
            guard let bookProvider, bookProvider.isAvailable else {
                setState(
                    error: BookPluginError.initialization(
                        reason: String(localized: "Disk not found", bundle: .module)
                    ),
                    generation: generation
                )
                return
            }
            if Self.verbose { os_log("\(self.t)✅ reloadProvider: 数据 Provider 就绪") }
            setState(generation: generation)
        }
    }

    func handleStorageLocationChanged() {
        if Self.verbose { os_log("\(Self.t)🔁 存储位置变化") }
        storageLocationDidChangeNotice = UUID()
        reloadContainer()
    }

    private func setState(error: Error? = nil, generation: Int) {
        guard generation == initGeneration else { return }
        self.error = error
        isLoading = false
    }
}

import Combine
import Foundation
import ProviderBook
import OSLog
import SwiftUI
import MagicKit

/// 书籍根容器的集中状态。
///
/// 数据库容器和仓库完全由数据层管理；此 ViewModel 只负责向根视图报告
/// 数据层是否就绪（经 `BookRootCapability`，见 Capabilities 目录）以及
/// 存储位置变化。
@MainActor
final class BookRootViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var error: Error?
    @Published private(set) var isLoading = true
    @Published var storageLocationDidChangeNotice = UUID()

    /// 书库能力（Capabilities 目录收窄）。
    ///
    /// **强持有**：入口与本容器各自持有，入口 `teardownRootState` 先释放
    /// 本容器再释放 Adapter；Adapter 内部对 Provider 为 `weak`，强持有能力
    /// 不会延长数据层 Provider 的生命周期。
    private let books: (any BookRootCapability)?
    private var initGeneration = 0

    init(books: (any BookRootCapability)?) {
        self.books = books
    }

    func reloadContainer() {
        initGeneration += 1
        let generation = initGeneration
        isLoading = true
        error = nil
        if Self.verbose { os_log("\(self.t)🔄 reloadProvider #\(generation)") }

        Task { @MainActor in
            guard let books, books.isAvailable else {
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

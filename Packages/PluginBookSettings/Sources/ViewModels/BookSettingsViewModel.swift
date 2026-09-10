import Foundation
import OSLog
import ProviderBook
import SwiftUI
import MagicKit

/// 书籍设置的刷新状态容器（迁移 Phase 5）。
///
/// 持有刷新令牌，存储位置变化时递增以触发设置视图刷新；
/// 取代原 `BookSettingsPluginView` 的 `@State refreshToken` 与
/// `BookSettingsStorageChangeModifier`。
@MainActor
final class BookSettingsViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var refreshToken = 0
    let bookDisk: @MainActor () -> URL?

    init(bookDisk: @escaping @MainActor () -> URL?) {
        self.bookDisk = bookDisk
    }

    func handleStorageLocationChanged() {
        refreshToken += 1
        if Self.verbose { os_log("\(Self.t)🔁 存储位置变化，刷新令牌 → \(self.refreshToken)") }
    }
}

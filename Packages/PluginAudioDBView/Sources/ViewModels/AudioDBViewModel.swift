import Foundation
import MagicKit

/// 音频数据库视图的排序 UI 状态容器（迁移 Phase 2）。
///
/// 排序开始/完成事件由 `AudioDatabaseObserver` 驱动；View 只读
/// `isSorting` / `sortMode` 做 UI 表现，不再直接订阅数据库排序通知。
@MainActor
final class AudioDBViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var isSorting = false
    @Published private(set) var sortMode: SortMode = .none

    func handleSorting(mode: String?) {
        isSorting = true
        let normalized = (mode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        sortMode = SortMode(rawValue: normalized) ?? .none
    }

    func handleSortDone() {
        isSorting = false
    }

    /// 从通知字符串解析排序模式（纯函数，供测试与复用）。
    nonisolated static func sortMode(from string: String) -> SortMode {
        let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return SortMode(rawValue: normalized) ?? .none
    }

    /// 排序模式枚举。
    enum SortMode: String {
        case random
        case order
        case none

        var icon: String {
            switch self {
            case .random: return "shuffle"
            case .order: return "arrow.up.arrow.down"
            case .none: return "arrow.triangle.2.circlepath"
            }
        }

        var description: String {
            switch self {
            case .random: return String(localized: "Shuffling...", bundle: .module)
            case .order: return String(localized: "Sorting in Order...", bundle: .module)
            case .none: return String(localized: "Sorting...", bundle: .module)
            }
        }
    }
}

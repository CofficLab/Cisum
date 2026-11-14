import Foundation

/// 音频仓库设置页的**展示分支判定**。
///
/// 与 `AudioListLoadPolicy` 同源思路：把视图里的 `if` 判定抽成纯函数，
/// 使状态组合（加载中 / 空库 / 失败 / 有内容）可被单测覆盖，
/// 而不必构造整个 SwiftUI 视图树。
enum AudioDBSettingPresentation {

    /// 列表区域的四种互斥状态。
    enum ListState: Equatable {
        /// 首次加载且暂无数据 → 显示加载指示。
        case loading
        /// 加载完成但库为空 → 显示空态。
        case empty
        /// 已有数据 → 显示内容。
        case content
        /// 加载失败 → 显示错误。
        case error(hasError: Bool)
    }

    /// 判定列表应展示哪种状态。
    ///
    /// 注意「加载中」优先于「空」：正在加载时不应闪现空态提示，
    /// 否则用户会误以为仓库本来就是空的。
    static func listState(
        isLoading: Bool,
        isLoadingMore: Bool,
        urlCount: Int,
        hasError: Bool
    ) -> ListState {
        if hasError {
            return .error(hasError: true)
        }
        if isLoading && urlCount == 0 {
            return .loading
        }
        if urlCount == 0 {
            return .empty
        }
        return .content
    }

    /// 加载更多时是否显示底部指示器。
    ///
    /// 仅在「已有内容且正在加载下一页」时显示，避免与首次加载指示重叠，
    /// 也避免空列表下方出现无意义的转圈。
    static func shouldShowLoadingMoreIndicator(
        isLoadingMore: Bool,
        urlCount: Int
    ) -> Bool {
        isLoadingMore && urlCount > 0
    }

    /// 诊断值缺失时是否显示 "nil" 占位。
    ///
    /// 诊断链路要求每项都可见，缺失时显式标注比留空更容易排查。
    static func diagnosticDisplayValue(_ value: String?) -> String {
        value ?? "nil"
    }

    /// 仓库不可用时是否展示完整诊断链路。
    static func shouldShowDiagnostics(diskAvailable: Bool) -> Bool {
        !diskAvailable
    }

    /// 展示模式切换是否需要重置列表。
    ///
    /// 列表 / 目录树共用同一份数据源，切换时无需重新加载；
    /// 返回 false 表示切换是纯粹的展示行为。
    static func requiresReloadOnModeSwitch(mode: Int) -> Bool {
        mode < 0
    }
}

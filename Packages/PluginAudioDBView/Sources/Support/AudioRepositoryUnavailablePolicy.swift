import Foundation

/// 音频库「仓库不可用」时的加载结果策略。
///
/// 首启引导期间存储位置尚未配置，`audioDisk` 必然为 nil；此时欢迎层已经
/// 解释了必须先选择存储位置，再弹通用仓库错误弹窗只会用模态遮罩盖住引导，
/// 并吞掉用户点击（含「继续」按钮）。因此仅在**已配置存储**的前提下才把
/// 不可用视为真实故障。
enum AudioRepositoryUnavailablePolicy {
    /// 仓库不可用时是否应向用户展示错误弹窗。
    ///
    /// - Parameters:
    ///   - hasUsableStorageLocation: 是否已配置可用存储位置。
    ///   - isRepositoryAvailable: 音频库当前是否可用。
    static func shouldPresentErrorNotice(
        hasUsableStorageLocation: Bool,
        isRepositoryAvailable: Bool
    ) -> Bool {
        hasUsableStorageLocation && !isRepositoryAvailable
    }
}

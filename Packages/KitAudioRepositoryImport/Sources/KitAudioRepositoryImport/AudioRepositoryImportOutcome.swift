import Foundation

/// 一次仓库导入的结果。
///
/// 本 Kit 只负责**机械流程**（过滤 → 复制 → 同步），不持有资源包，
/// 因此不产出任何面向用户的文案：调用方按自己的语言环境把结果映射成提示。
public enum AudioRepositoryImportOutcome: Equatable {
    /// 导入成功；`skippedUnsupported` 是被跳过的、不受支持的文件数量。
    case imported(skippedUnsupported: Int)

    /// 没有可导入的文件（全部不是受支持的音频格式，或都是文件夹）。
    case noImportableFiles

    /// 仓库目录不可用（存储位置尚未就绪）。
    case storageUnavailable

    /// 音频库未就绪：文件已复制但无法入索引，已回滚复制结果。
    case libraryUnavailable

    /// 没有读取到原始文件的权限。
    case permissionDenied

    /// 其它失败原因（人类可读的原因描述）。
    case failed(reason: String)
}

/// 导入过程中抛出的错误。
public enum AudioRepositoryImportError: LocalizedError {
    /// 没有读取到原始文件的权限。
    case permissionDenied

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission to access the original file was denied"
        }
    }
}

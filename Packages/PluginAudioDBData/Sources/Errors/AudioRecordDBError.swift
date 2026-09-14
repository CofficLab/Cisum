import Foundation

// MARK: - 音频记录数据库错误

/// 音频记录写库与查询过程中的错误。
public enum AudioRecordDBError: Error, LocalizedError {
    /// 切换喜欢状态时发生错误
    case ToggleLikeError(Error)
    /// 未找到指定 URL 的音频
    case AudioNotFound(URL)
    /// 数据库操作失败
    case databaseOperation(operation: String, underlying: String)
    /// 数据保存失败
    case saveFailed(Error)
    /// 数据删除失败
    case deleteFailed(Error)

    public var errorDescription: String? {
        switch self {
        case let .ToggleLikeError(error):
            return audioErrorString("Failed to toggle like status: \(error.localizedDescription)")
        case let .AudioNotFound(url):
            return audioErrorString("Audio not found: \(url.lastPathComponent)")
        case let .databaseOperation(operation, underlying):
            return audioErrorString("Database operation failed [\(operation)]: \(underlying)")
        case let .saveFailed(error):
            return audioErrorString("Failed to save data: \(error.localizedDescription)")
        case let .deleteFailed(error):
            return audioErrorString("Failed to delete data: \(error.localizedDescription)")
        }
    }

    public var failureReason: String? {
        switch self {
        case .ToggleLikeError:
            return audioErrorString("The database update operation failed.")
        case .AudioNotFound:
            return audioErrorString("The requested audio file does not exist.")
        case .databaseOperation:
            return audioErrorString("The database operation failed.")
        case .saveFailed:
            return audioErrorString("The data persistence operation failed.")
        case .deleteFailed:
            return audioErrorString("The data deletion operation failed.")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .ToggleLikeError:
            return audioErrorString("Try again later.")
        case .AudioNotFound:
            return audioErrorString("Check whether the file exists or sync again.")
        case .databaseOperation:
            return audioErrorString("Try restarting the app or resetting the database.")
        case .saveFailed, .deleteFailed:
            return audioErrorString("Check disk space and permissions.")
        }
    }
}

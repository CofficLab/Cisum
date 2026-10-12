import Foundation

// MARK: - 音频模型错误

/// 音频模型层的数据校验与文件状态错误。
public enum AudioModelError: Error, LocalizedError {
    case deleteFailed
    case dbNotFound
    case invalidData(String)
    case fileCorrupted(URL)

    public var errorDescription: String? {
        switch self {
        case .deleteFailed:
            return audioErrorString("Delete operation failed")
        case .dbNotFound:
            return audioErrorString("Database not found")
        case let .invalidData(reason):
            return audioErrorString("Invalid data: \(reason)")
        case let .fileCorrupted(url):
            return audioErrorString("File is corrupted: \(url.lastPathComponent)")
        }
    }

    public var failureReason: String? {
        switch self {
        case .deleteFailed:
            return audioErrorString("File system permissions are insufficient or the file is in use.")
        case .dbNotFound:
            return audioErrorString("The database connection was lost or the database file is corrupted.")
        case .invalidData:
            return audioErrorString("The data format is not as expected.")
        case .fileCorrupted:
            return audioErrorString("The audio file may be corrupted or incomplete.")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .deleteFailed:
            return audioErrorString("Check file permissions or close related apps.")
        case .dbNotFound:
            return audioErrorString("Try restarting the app or syncing again.")
        case .invalidData:
            return audioErrorString("Check the data source or download again.")
        case .fileCorrupted:
            return audioErrorString("Download again or choose another audio file.")
        }
    }
}

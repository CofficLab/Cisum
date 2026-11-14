import Foundation

/// 音频播放器相关错误类型
public enum MagicError: LocalizedError {
    /// 文件操作相关错误
    case fileError(String)
    /// 网络相关错误
    case networkError(String)
    /// 音频解码错误
    case decodingError(String)
    /// 音频编码错误
    case encodingError(String)
    /// 播放器错误
    case playerError(String)
    /// 无效的音频格式
    case invalidFormat(String)
    /// 权限错误
    case permissionDenied(String)
    /// 未实现的功能
    case notImplemented(String)
    /// 未知错误
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileError(let message):
            return "File Error: \(message)"
        case .networkError(let message):
            return "Network Error: \(message)"
        case .decodingError(let message):
            return "Decoding Error: \(message)"
        case .encodingError(let message):
            return "Encoding Error: \(message)"
        case .playerError(let message):
            return "Player Error: \(message)"
        case .invalidFormat(let message):
            return "Invalid Format: \(message)"
        case .permissionDenied(let message):
            return "Permission Denied: \(message)"
        case .notImplemented(let message):
            return "Not Implemented: \(message)"
        case .unknown(let message):
            return "Unknown Error: \(message)"
        }
    }
}

// MARK: - 错误处理扩展
extension MagicError {
    /// 创建一个包装了原始错误的 MagicError
    /// - Parameter error: 原始错误
    /// - Returns: 包装后的 MagicError
    public static func wrap(_ error: Error) -> MagicError {
        if let magicError = error as? MagicError {
            return magicError
        }
        return .unknown(error.localizedDescription)
    }
}

import Foundation

// MARK: - 音频插件核心错误

/// 音频插件的配置与运行环境相关错误。
public enum AudioPluginError: Error, LocalizedError {
    case hostNotConfigured
    case NoNextAsset
    case NoPrevAsset
    case NoDisk
    case initialization(reason: String)
    case diskAccess(url: URL, underlying: String)
    case configurationError(setting: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .hostNotConfigured:
            return audioErrorString("Audio plugin host configuration is incomplete")
        case .NoNextAsset:
            return audioErrorString("No next audio file")
        case .NoPrevAsset:
            return audioErrorString("No previous audio file")
        case .NoDisk:
            return audioErrorString("Unable to access disk")
        case let .initialization(reason):
            return audioErrorString("Initialization failed: \(reason)")
        case let .diskAccess(url, underlying):
            return audioErrorString("Disk access failed [\(url.lastPathComponent)]: \(underlying)")
        case let .configurationError(setting, reason):
            return audioErrorString("Configuration error [\(setting)]: \(reason)")
        }
    }

    public var failureReason: String? {
        switch self {
        case .hostNotConfigured:
            return audioErrorString("The app has not injected database and storage path configuration.")
        case .NoNextAsset:
            return audioErrorString("The current audio is the last item in the playlist.")
        case .NoPrevAsset:
            return audioErrorString("The current audio is the first item in the playlist.")
        case .NoDisk:
            return audioErrorString("The specified disk path does not exist or cannot be accessed.")
        case .initialization:
            return audioErrorString("An error occurred while initializing the app.")
        case .diskAccess:
            return audioErrorString("The specified disk location cannot be accessed.")
        case .configurationError:
            return audioErrorString("There is a problem with the app configuration.")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .hostNotConfigured:
            return audioErrorString("Check the app startup flow.")
        case .NoNextAsset, .NoPrevAsset:
            return audioErrorString("Check the playlist or switch to another playback mode.")
        case .NoDisk:
            return audioErrorString("Check the disk path and access permissions.")
        case .initialization:
            return audioErrorString("Try restarting the app.")
        case .diskAccess:
            return audioErrorString("Check disk space and access permissions.")
        case .configurationError:
            return audioErrorString("Check app settings or reinstall the app.")
        }
    }
}

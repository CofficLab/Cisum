import Foundation
import SwiftUI

// MARK: - Book Plugin Errors

public enum BookPluginError: Error, LocalizedError {
    case configurationMissing
    case NoNextAsset
    case NoPrevAsset
    case NoDisk
    case DiskNotFound
    case initialization(reason: String)

    public var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return String(localized: "Book plugin host configuration is incomplete", bundle: .module)
        case .NoNextAsset:
            return String(localized: "No next chapter or file", bundle: .module)
        case .NoPrevAsset:
            return String(localized: "No previous chapter or file", bundle: .module)
        case .NoDisk:
            return String(localized: "Unable to access disk", bundle: .module)
        case .DiskNotFound:
            return String(localized: "Disk not found", bundle: .module)
        case .initialization(let reason):
            return String(localized: "Initialization failed: \(reason)", bundle: .module)
        }
    }

    public var failureReason: String? {
        switch self {
        case .configurationMissing:
            return String(localized: "The app has not injected database and storage path configuration.", bundle: .module)
        case .NoNextAsset:
            return String(localized: "The current item is already the last item.", bundle: .module)
        case .NoPrevAsset:
            return String(localized: "The current item is already the first item.", bundle: .module)
        case .NoDisk:
            return String(localized: "The specified disk path does not exist or cannot be accessed.", bundle: .module)
        case .DiskNotFound:
            return String(localized: "The specified disk path does not exist or cannot be accessed.", bundle: .module)
        case .initialization:
            return String(localized: "An error occurred while initializing the plugin.", bundle: .module)
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .configurationMissing:
            return String(localized: "Check the app startup flow.", bundle: .module)
        case .NoNextAsset, .NoPrevAsset:
            return String(localized: "Check the playback order or choose another item.", bundle: .module)
        case .NoDisk:
            return String(localized: "Check disk permissions and path settings.", bundle: .module)
        case .DiskNotFound:
            return String(localized: "Check disk permissions and path settings.", bundle: .module)
        case .initialization:
            return String(localized: "Try restarting the app or checking settings.", bundle: .module)
        }
    }
}

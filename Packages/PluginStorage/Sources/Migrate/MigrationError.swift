import Foundation

enum MigrationError: LocalizedError {
    case sourceDirectoryNotFound
    case targetDirectoryNotFound
    case fileOperationFailed(String)
    case migrationCancelled
    
    var errorDescription: String? {
        switch self {
        case .sourceDirectoryNotFound:
            return String(localized: "Source folder not found", bundle: .module)
        case .targetDirectoryNotFound:
            return String(localized: "Target folder not found", bundle: .module)
        case .fileOperationFailed(let message):
            return String(localized: "File operation failed: \(message)", bundle: .module)
        case .migrationCancelled:
            return String(localized: "Migration was cancelled. Some files may have already been migrated.", bundle: .module)
        }
    }
}

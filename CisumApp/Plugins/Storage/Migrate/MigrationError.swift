import Foundation

enum MigrationError: LocalizedError {
    case sourceDirectoryNotFound
    case targetDirectoryNotFound
    case fileOperationFailed(String)
    case migrationCancelled
    
    var errorDescription: String? {
        switch self {
        case .sourceDirectoryNotFound:
            return "无法找到源文件夹"
        case .targetDirectoryNotFound:
            return "无法找到目标文件夹"
        case .fileOperationFailed(let message):
            return "文件操作失败: \(message)"
        case .migrationCancelled:
            return "迁移已取消，部分文件可能已经迁移"
        }
    }
}

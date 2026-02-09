import SwiftUI
import MagicKit


struct FileIconView: View {
    let url: URL
    
    // 计算属性：判断是否为目录
    private var isDirectory: Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
    
    private var fileIcon: String {
        // 如果是目录，返回文件夹图标
        if isDirectory {
            if let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey]),
               values.isUbiquitousItem == true {
                return "icloud.fill"
            }
            return "folder.fill"
        }
        
        // 根据文件扩展名返回对应图标
        switch url.pathExtension.lowercased() {
        case "mp3", "m4a", "wav", "aac":
            return "music.note"
        case "mp4", "mov", "avi", "mkv":
            return "film"
        case "jpg", "jpeg", "png", "gif":
            return "photo"
        case "pdf":
            return "doc.fill"
        case "txt", "md":
            return "doc.text.fill"
        default:
            return "doc.fill"
        }
    }
    
    var body: some View {
        Image(systemName: fileIcon)
            .foregroundColor(.secondary)
    }
}

extension Notification.Name {
    static let fileStatusUpdated = Notification.Name("fileStatusUpdated")
}

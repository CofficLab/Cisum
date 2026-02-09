import SwiftUI
import MagicKit

import OSLog

struct FileSizeView: View, SuperLog {
    nonisolated static let emoji = "🫘"
    
    let url: URL
    @State private var size: Int64?
    
    var body: some View {
        Group {
            if let size = size {
                Text(formatFileSize(size))
            } else {
                Text("计算中...")
                    .foregroundStyle(.secondary)
            }
        }
        .task(priority: .background) {
            updateSize()
        }
    }

    private func updateSize(verbose: Bool = false) {
        Task.detached(priority: .background) {
            if verbose {
                os_log("\(self.t)UpdateSize: \(url.path)")
            }
            
            let size: Int64 = {
                var totalSize: Int64 = 0
                
                guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                      let isDirectory = resourceValues.isDirectory else {
                    return (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                }
                
                if isDirectory {
                    guard let urls = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])?.allObjects as? [URL] else {
                        return 0
                    }
                    
                    for fileURL in urls {
                        if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                            totalSize += Int64(fileSize)
                        }
                    }
                    return totalSize
                } else {
                    return (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                }
            }()
            
            await setSize(size)
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    @MainActor
    private func setSize(_ size: Int64) {
        Task(priority: .background) {
            self.size = size
        }
    }
}

#Preview {
    FileSizeView(url: URL(filePath: "/Users/user/Desktop"))
} 

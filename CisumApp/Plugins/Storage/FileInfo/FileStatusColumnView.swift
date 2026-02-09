import MagicKit

import OSLog
import SwiftUI

struct FileStatusColumnView: View, SuperLog {
    nonisolated static let emoji: String = "🥩"

    let url: URL
    @State private var fileStatus: String = "检查中..."
    @State private var isChecking: Bool = true
    @State private var statusColor: Color = .gray

    @MainActor
    private static var statusCache: [String: (status: String, color: Color)] = [:]

    var body: some View {
        Text(fileStatus)
            .foregroundColor(statusColor)
            .task {
                checkFileStatus(verbose: false)
            }
    }

    private func checkFileStatus(verbose: Bool) {
        Task.detached(priority: .high) {
            let path = url.path(percentEncoded: false)
            
            // 检查缓存
            if let cached = await MainActor.run(body: { Self.statusCache[path] }) {
                await updateState(fileStatus: cached.status, statusColor: cached.color, isChecking: false)
                if verbose {
                    os_log("\(Self.t)📦 Using cached status for \(path)")
                }
                return
            }
            
            if verbose {
                os_log("\(Self.t)🔍 Checking file status for \(path)")
            }

            // 使用新的 URL 扩展方法
            if url.isFolder {
                await checkDirectoryStatus(url)
            } else if url.checkIsICloud(verbose: false) {
                await checkSingleFileStatus(url.isDownloaded)
            } else {
                let status = "本地文件"
                let color: Color = .primary
                await MainActor.run {
                    Self.statusCache[path] = (status, color)
                }
                await updateState(fileStatus: status, statusColor: color, isChecking: false)
            }
        }
    }

    private func checkSingleFileStatus(_ isDownloaded: Bool, verbose: Bool = false) {
        Task.detached(priority: .background) {
            if verbose {
                os_log("\(Self.t)🔍 Checking single file status for \(url.path(percentEncoded: false))")
            }

            let (status, color) = if isDownloaded {
                ("已下载", Color.green)
            } else {
                ("未下载", Color.orange)
            }

            let path = url.path(percentEncoded: false)
            await MainActor.run {
                Self.statusCache[path] = (status, color)
            }

            await updateState(fileStatus: status, statusColor: color, isChecking: false)
        }
    }

    private func checkDirectoryStatus(_ directoryURL: URL, verbose: Bool = false) {
        Task.detached(priority: .background) {
            if verbose {
                os_log("\(Self.t)🔍 Checking directory status for \(directoryURL.path(percentEncoded: false))")
            }

            // 使用 flatten() 获取所有文件
            let files = directoryURL.flatten()
            var fileStats = (downloaded: 0, notDownloaded: 0)

            for file in files where file.checkIsICloud(verbose: false) {
                if file.isDownloaded {
                    fileStats.downloaded += 1
                } else {
                    fileStats.notDownloaded += 1
                }
            }

            let (status, color) = if fileStats.downloaded > 0 || fileStats.notDownloaded > 0 {
                ("\(fileStats.downloaded)个已下载, \(fileStats.notDownloaded)个未下载",
                 fileStats.downloaded > 0 ? Color.green : Color.orange)
            } else {
                ("本地目录", Color.primary)
            }

            let path = directoryURL.path(percentEncoded: false)
            await MainActor.run {
                Self.statusCache[path] = (status, color)
            }
            
            await updateState(fileStatus: status, statusColor: color, isChecking: false)
        }
    }

    @MainActor
    private func updateState(fileStatus: String, statusColor: Color, isChecking: Bool) {
        Task(priority: .background) {
            self.fileStatus = fileStatus
            self.statusColor = statusColor
            self.isChecking = isChecking
        }
    }
}

#Preview {
    FileStatusColumnView(url: URL(filePath: "/Users/user/Downloads/test.txt"))
}

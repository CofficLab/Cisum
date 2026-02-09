import Foundation
import SwiftUI

struct FileStatus: Identifiable {
    let id = UUID()
    let name: String
    let status: Status
    let downloadStatus: DownloadStatus
    let url: URL?
    let isDirectory: Bool
    
    init(
        name: String,
        status: Status,
        downloadStatus: DownloadStatus,
        url: URL? = nil,
        isDirectory: Bool = false
    ) {
        self.name = name
        self.status = status
        self.downloadStatus = downloadStatus
        self.url = url
        self.isDirectory = isDirectory
    }
    
    enum Status: Equatable {
        case idle
        case pending
        case processing
        case completed
        case failed(String)
        
        var color: Color {
            switch self {
            case .idle, .pending: return .secondary
            case .processing: return .accentColor
            case .completed: return .green
            case .failed: return .red
            }
        }
    }
    
    enum DownloadStatus: Equatable {
        case notDownloaded
        case checking(current: Int, total: Int)  // 修改 checking 状态，添加进度信息
        case checkingDirectory(String, Int, Int)  // 目录名，当前项，总项数
        case downloading(progress: Double)
        case downloaded
        case local
        case directoryStatus(total: Int, downloaded: Int, downloading: Int, notDownloaded: Int)
        
        var color: Color {
            switch self {
            case .notDownloaded:
                return .secondary
            case .checking, .checkingDirectory:
                return .orange
            case .downloading:
                return .blue
            case .downloaded, .local:
                return .accentColor
            case .directoryStatus:
                return .accentColor
            }
        }
        
        var description: String {
            switch self {
            case .local:
                return "本地文件"
            case .downloaded:
                return "已下载"
            case .notDownloaded:
                return "未下载"
            case .downloading(let progress):
                return "下载中 \(Int(progress * 100))%"
            case .checking(let current, let total):
                if total > 0 {
                    return "检查中 (\(current)/\(total))"
                } else {
                    return "检查中"
                }
            case .checkingDirectory(let name, let current, let total):
                return "正在检查目录 \(name) (\(current)/\(total))"
            case .directoryStatus(_, let downloaded, let downloading, let notDownloaded):
                var parts: [String] = []
                if downloaded > 0 {
                    parts.append("\(downloaded) 已下载")
                }
                if downloading > 0 {
                    parts.append("\(downloading) 下载中")
                }
                if notDownloaded > 0 {
                    parts.append("\(notDownloaded) 未下载")
                }
                return parts.isEmpty ? "空文件夹" : parts.joined(separator: ", ")
            }
        }
    }
}

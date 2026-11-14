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

        static func normalizedProgress(_ progress: Double) -> Double {
            guard progress.isFinite else { return 0 }
            return min(max(progress, 0), 1)
        }

        static func percentText(for progress: Double) -> String {
            "\(Int(normalizedProgress(progress) * 100))%"
        }
        
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
                return String(localized: "Local File", bundle: .module)
            case .downloaded:
                return String(localized: "Downloaded", bundle: .module)
            case .notDownloaded:
                return String(localized: "Not Downloaded", bundle: .module)
            case .downloading(let progress):
                return String(localized: "Downloading \(Self.percentText(for: progress))", bundle: .module)
            case .checking(let current, let total):
                if total > 0 {
                    return String(localized: "Checking (\(current)/\(total))", bundle: .module)
                } else {
                    return String(localized: "Checking...", bundle: .module)
                }
            case .checkingDirectory(let name, let current, let total):
                return String(localized: "Checking folder \(name) (\(current)/\(total))", bundle: .module)
            case .directoryStatus(_, let downloaded, let downloading, let notDownloaded):
                var parts: [String] = []
                if downloaded > 0 {
                    parts.append(String(localized: "\(downloaded) downloaded", bundle: .module))
                }
                if downloading > 0 {
                    parts.append(String(localized: "\(downloading) downloading", bundle: .module))
                }
                if notDownloaded > 0 {
                    parts.append(String(localized: "\(notDownloaded) not downloaded", bundle: .module))
                }
                return parts.isEmpty ? String(localized: "Empty Folder", bundle: .module) : parts.joined(separator: ", ")
            }
        }
    }
}

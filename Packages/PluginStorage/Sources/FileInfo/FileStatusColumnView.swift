import MagicKit
import CisumUIComponents
import LumiUI

import OSLog
import SwiftUI

enum FileStatusResolutionPolicy {
    static func pathExistsIncludingSymlink(_ url: URL) -> Bool {
        if FileManager.default.fileExists(atPath: url.path) {
            return true
        }

        return (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }
}

enum FileStatusDirectoryScanPolicy {
    static func cloudDownloadStats(in directoryURL: URL) -> (downloaded: Int, notDownloaded: Int) {
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isUbiquitousItemKey,
                .ubiquitousItemDownloadingStatusKey,
            ],
            options: [.skipsHiddenFiles]
        ) else {
            return (downloaded: 0, notDownloaded: 0)
        }

        var stats = (downloaded: 0, notDownloaded: 0)
        for case let fileURL as URL in enumerator {
            guard isRegularFile(fileURL), fileURL.checkIsICloud(verbose: false) else {
                continue
            }

            if fileURL.isDownloaded {
                stats.downloaded += 1
            } else {
                stats.notDownloaded += 1
            }
        }

        return stats
    }

    private static func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }
}

struct FileStatusColumnView: View, SuperLog {
    nonisolated static let emoji: String = "🥩"

    let url: URL
    @State private var fileStatus: String = String(localized: "Checking...", bundle: .module)
    @State private var isChecking: Bool = true
    @State private var statusColor: Color = .gray

    var body: some View {
        Text(fileStatus)
            .foregroundColor(statusColor)
            .task(id: url) {
                fileStatus = String(localized: "Checking...", bundle: .module)
                statusColor = .gray
                isChecking = true
                await checkFileStatus(verbose: false)
            }
    }

    private func checkFileStatus(verbose: Bool) async {
        if verbose {
            os_log("\(Self.t)🔍 Checking file status for \(url.path(percentEncoded: false))")
        }

        let requestedURL = url
        let result = await Task.detached(priority: .background) {
            Self.resolveStatus(for: requestedURL, verbose: verbose)
        }.value

        guard !Task.isCancelled,
              FileInfoCellLoadPolicy.shouldApplyResult(currentURL: url, requestedURL: requestedURL) else {
            return
        }

        updateState(fileStatus: result.status, statusColor: result.color, isChecking: false)
    }

    nonisolated static func resolveStatus(for url: URL, verbose: Bool) -> (status: String, color: Color) {
        if verbose {
            os_log("\(Self.t)🔍 Checking file status for \(url.path(percentEncoded: false))")
        }

        guard !url.isFileURL || FileStatusResolutionPolicy.pathExistsIncludingSymlink(url) else {
            return (String(localized: "Missing", bundle: .module), Color.red)
        }

        if url.isFolder {
            return resolveDirectoryStatus(url)
        } else if url.checkIsICloud(verbose: false) {
            return resolveSingleFileStatus(url.isDownloaded)
        } else {
            return (String(localized: "Local File", bundle: .module), Color.primary)
        }
    }

    nonisolated private static func resolveSingleFileStatus(_ isDownloaded: Bool) -> (status: String, color: Color) {
        if isDownloaded {
            (String(localized: "Downloaded", bundle: .module), Color.green)
        } else {
            (String(localized: "Not Downloaded", bundle: .module), Color.orange)
        }
    }

    nonisolated private static func resolveDirectoryStatus(_ directoryURL: URL) -> (status: String, color: Color) {
        let fileStats = FileStatusDirectoryScanPolicy.cloudDownloadStats(in: directoryURL)

        if fileStats.downloaded > 0 || fileStats.notDownloaded > 0 {
            return (String(localized: "\(fileStats.downloaded) downloaded, \(fileStats.notDownloaded) not downloaded", bundle: .module),
                    fileStats.downloaded > 0 ? Color.green : Color.orange)
        } else {
            return (String(localized: "Local Folder", bundle: .module), Color.primary)
        }
    }

    @MainActor
    private func updateState(fileStatus: String, statusColor: Color, isChecking: Bool) {
        self.fileStatus = fileStatus
        self.statusColor = statusColor
        self.isChecking = isChecking
    }
}

#Preview {
    FileStatusColumnView(url: URL(filePath: "/Users/user/Downloads/test.txt"))
}

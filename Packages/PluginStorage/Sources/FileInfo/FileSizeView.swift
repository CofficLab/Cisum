import MagicKit
import SwiftUI
import CisumUIComponents
import LumiUI

import OSLog

enum FileInfoCellLoadPolicy {
    static func shouldApplyResult(currentURL: URL, requestedURL: URL) -> Bool {
        representsSameFile(currentURL, requestedURL)
    }

    private static func representsSameFile(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.isSameFileLocation(as: rhs)
    }
}

enum FileSizeReadPolicy {
    static func fileSize(from attributes: [FileAttributeKey: Any]) -> Int64 {
        if let number = attributes[.size] as? NSNumber {
            return normalizedFileSize(number.int64Value)
        }

        if let size = attributes[.size] as? Int64 {
            return normalizedFileSize(size)
        }

        return 0
    }

    static func normalizedFileSize(_ size: Int64) -> Int64 {
        max(size, 0)
    }
}

enum FileSizeCalculationPolicy {
    static func size(for url: URL) -> Int64 {
        guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),
              let isDirectory = resourceValues.isDirectory else {
            let attributes = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
            return FileSizeReadPolicy.fileSize(from: attributes)
        }

        guard isDirectory else {
            let attributes = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
            return FileSizeReadPolicy.fileSize(from: attributes)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true,
                  let fileSize = values.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }

        return totalSize
    }
}

struct FileSizeView: View, SuperLog {
    nonisolated static let emoji = "🫘"
    
    let url: URL
    @State private var size: Int64?
    
    var body: some View {
        Group {
            if let size = size {
                Text(formatFileSize(size))
            } else {
                Text("Calculating...", bundle: .module)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: url, priority: .background) {
            size = nil
            await updateSize()
        }
    }

    private func updateSize(verbose: Bool = false) async {
        let requestedURL = url
        let calculatedSize = await Task.detached(priority: .background) {
            if verbose {
                os_log("\(self.t)UpdateSize: \(requestedURL.path)")
            }

            return FileSizeCalculationPolicy.size(for: requestedURL)
        }.value

        guard !Task.isCancelled,
              FileInfoCellLoadPolicy.shouldApplyResult(currentURL: url, requestedURL: requestedURL) else {
            return
        }

        size = calculatedSize
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

#Preview {
    FileSizeView(url: URL(filePath: "/Users/user/Desktop"))
} 

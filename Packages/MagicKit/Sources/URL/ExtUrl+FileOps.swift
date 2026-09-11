import Foundation
import Combine
import CryptoKit
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
    import AppKit
#elseif os(iOS)
    import UIKit
#endif

enum URLDownloadAvailabilityPolicy {
    static func isDownloaded(
        fileExists: Bool,
        isUbiquitousItem: Bool?,
        downloadingStatus: URLUbiquitousItemDownloadingStatus?
    ) -> Bool {
        if isUbiquitousItem == true {
            return downloadingStatus == .current
        }

        if let downloadingStatus {
            return downloadingStatus == .current
        }

        return fileExists
    }
}

enum URLDownloadProgressPolicy {
    static func normalizedFraction(percentDownloaded: Double?) -> Double {
        guard let percentDownloaded, percentDownloaded.isFinite else { return 0 }
        return min(max(percentDownloaded / 100, 0), 1)
    }

    static func normalizedFraction(downloadedSize: Int?, totalSize: Int?) -> Double {
        guard let downloadedSize,
              let totalSize,
              totalSize > 0 else {
            return 0
        }

        return min(max(Double(downloadedSize) / Double(totalSize), 0), 1)
    }
}

enum URLDirectoryContainmentPolicy {
    static func contains(_ childPath: String, inDirectory parentPath: String) -> Bool {
        childPath == parentPath || childPath.hasPrefix(childPrefix(for: parentPath))
    }

    private static func childPrefix(for parentPath: String) -> String {
        parentPath.hasSuffix("/") ? parentPath : parentPath + "/"
    }
}

public enum URLOpenActionPolicy {
    public static func canOpen(_ url: URL) -> Bool {
        guard url.isFileURL else {
            return true
        }

        return FileManager.default.fileExists(atPath: url.path)
    }

    public static func canRevealInFinder(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }

        if FileManager.default.fileExists(atPath: url.path) {
            return true
        }

        return (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    public static func buttonAccessibilityLabel(for url: URL) -> String {
        let target = buttonTargetName(for: url)
        guard !target.isEmpty else { return "Open" }

        return "Open \(target)"
    }

    private static func buttonTargetName(for url: URL) -> String {
        if url.isFileURL {
            return url.lastPathComponent
        }

        return url.host ?? url.absoluteString
    }
}

/// URL 扩展：文件操作基础方法
public extension URL {
    /// File/display title without the path extension.
    var title: String {
        deletingPathExtension().lastPathComponent
    }

    /// Whether the URL points to a directory.
    var isFolder: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? hasDirectoryPath
    }

    /// Alias for callers that use directory terminology.
    var isDirectory: Bool {
        isFolder
    }

    /// Whether the URL points to an existing directory.
    var isDirExist: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Whether the URL does not point to an existing directory.
    var isNotDirExist: Bool {
        !isDirExist
    }

    /// Whether the URL does not point to an existing file.
    var isNotFileExist: Bool {
        !FileManager.default.fileExists(atPath: path)
    }

    /// Whether a path is occupied, including by a broken symbolic link.
    var pathExistsIncludingSymbolicLink: Bool {
        FileManager.default.fileExists(atPath: path) || isSymbolicLinkPath
    }

    /// Whether the URL does not point to a directory.
    var isNotFolder: Bool {
        !isFolder
    }

    /// Whether two file URLs resolve to the same filesystem location.
    func isSameFileLocation(as other: URL) -> Bool {
        guard isFileURL, other.isFileURL else {
            return standardized.absoluteString == other.standardized.absoluteString
        }

        return canonicalFileLocationIdentity == other.canonicalFileLocationIdentity
    }

    private var canonicalFileLocationIdentity: String {
        if isDanglingSymbolicLinkPath {
            return standardizedFileURL.path
        }

        return resolvingSymlinksInPath().standardizedFileURL.path
    }

    private var isDanglingSymbolicLinkPath: Bool {
        isSymbolicLinkPath && !FileManager.default.fileExists(atPath: path)
    }

    /// Whether a local/iCloud file is available on disk.
    var isDownloaded: Bool {
        let fileExists = isFileURL && FileManager.default.fileExists(atPath: path)

        let values = try? resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
        ])

        return URLDownloadAvailabilityPolicy.isDownloaded(
            fileExists: fileExists,
            isUbiquitousItem: values?.isUbiquitousItem,
            downloadingStatus: values?.ubiquitousItemDownloadingStatus
        )
    }

    /// Whether an iCloud file is explicitly not downloaded.
    var isNotDownloaded: Bool {
        #if os(macOS)
            let values = try? resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            return values?.ubiquitousItemDownloadingStatus == .notDownloaded
        #else
            return false
        #endif
    }

    /// 文件内容是否已经落到本地磁盘，可以直接读取。
    ///
    /// 与 `isDownloaded` 的区别：`isDownloaded` 依赖 iCloud 的
    /// `ubiquitousItemDownloadingStatus`，而「优化 Mac 存储」下被驱逐的文件
    /// （`ls -lO` 显示 `dataless`、`st_blocks` 为 0）在该键上可能既不报
    /// `.notDownloaded` 也不报 `.current`，于是 `isDownloaded` 与 `isNotDownloaded`
    /// 同时为 false，下载流程既不发起请求、也无法判定完成。
    ///
    /// 这里改用文件实际占用的磁盘空间判断（dataless 占位文件的已分配空间恒为 0），
    /// 不依赖 iCloud 状态键，任何进程与权限下都能可靠读取。
    var hasLocalContent: Bool {
        guard isFileURL, isFileExist else { return false }

        guard let values = try? resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .fileSizeKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
        ]) else {
            return true
        }

        // 只有 iCloud 项目才可能是「占位无内容」，其余一律视为本地可用
        guard values.isUbiquitousItem == true else { return true }

        // 空文件没有内容需要下载
        guard let fileSize = values.fileSize, fileSize > 0 else { return true }

        let allocatedSize = values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0
        return allocatedSize > 0
    }

    /// 创建文件如果不存在，返回自身
    func createIfNotExist() -> URL {
        if !FileManager.default.fileExists(atPath: self.path) {
            try? FileManager.default.createDirectory(
                at: self.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            FileManager.default.createFile(atPath: self.path, contents: nil)
        }
        return self
    }

    /// 读取文件内容
    func getContent() throws -> String {
        try String(contentsOf: self)
    }

    /// 删除当前 URL 指向的文件或目录。
    func delete() throws {
        guard FileManager.default.fileExists(atPath: path) || isSymbolicLinkPath else {
            return
        }
        try FileManager.default.removeItem(at: self)
    }

    private var isSymbolicLinkPath: Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil
    }

    /// 复制当前文件到目标位置。
    func copyTo(
        _ destination: URL,
        verbose: Bool = false,
        caller: String,
        downloadProgress: ((Double) -> Void)? = nil
    ) async throws {
        guard !isSameFileLocation(as: destination) else {
            throw MagicError.fileError("Cannot copy a file onto itself: \(lastPathComponent)")
        }

        guard !isDirectoryCopyIntoDescendant(destination) else {
            throw MagicError.fileError("Cannot copy a folder into itself: \(lastPathComponent)")
        }

        let sourceToCopy = copySourceURL()
        try await sourceToCopy.ensureLocalAvailability()

        if destination.pathExistsIncludingSymbolicLink {
            try destination.delete()
        }

        try FileManager.default.copyItem(at: sourceToCopy, to: destination)
    }

    private func copySourceURL() -> URL {
        let resolvedURL = resolvingSymlinksInPath().standardizedFileURL
        guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
            return self
        }

        return resolvedURL
    }

    private func isDirectoryCopyIntoDescendant(_ destination: URL) -> Bool {
        guard isFileURL, destination.isFileURL, isFolder else {
            return false
        }

        let sourcePath = resolvingSymlinksInPath().standardizedFileURL.path
        let destinationPath = destination.resolvingSymlinksInPath().standardizedFileURL.path
        return sourcePath != destinationPath
            && URLDirectoryContainmentPolicy.contains(destinationPath, inDirectory: sourcePath)
    }

    /// Ensure an iCloud-backed file has finished downloading before a caller reads or copies it.
    func ensureLocalAvailability(
        timeout: TimeInterval = 120,
        pollInterval: TimeInterval = 0.25
    ) async throws {
        guard checkIsICloud(verbose: false) else { return }

        // 以「内容是否已在本地」为唯一判据，而不依赖 isDownloaded / isNotDownloaded：
        // 被驱逐（dataless）的文件这两个值会同时为 false，既不会发起下载也无法判定完成。
        if hasLocalContent { return }

        // 无条件请求下载：该 API 对已下载/下载中的项目是幂等的，
        // 而 isNotDownloaded 为 false 并不代表内容确实在本地。
        try FileManager.default.startDownloadingUbiquitousItem(at: self)

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try Task.checkCancellation()

            var refreshedURL = self
            refreshedURL.removeAllCachedResourceValues()
            if refreshedURL.hasLocalContent {
                return
            }

            let nanoseconds = UInt64(max(pollInterval, 0.05) * 1_000_000_000)
            try await Task.sleep(nanoseconds: nanoseconds)
        }

        throw NSError(
            domain: "MagicKit.FileAvailability",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Timed out waiting for iCloud file to download: \(lastPathComponent)"
            ]
        )
    }

    /// Synchronous variant for non-async file workflows such as migration.
    func ensureLocalAvailabilitySync(
        timeout: TimeInterval = 120,
        pollInterval: TimeInterval = 0.25
    ) throws {
        guard checkIsICloud(verbose: false) else { return }

        if hasLocalContent { return }

        try FileManager.default.startDownloadingUbiquitousItem(at: self)

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            var refreshedURL = self
            refreshedURL.removeAllCachedResourceValues()
            if refreshedURL.hasLocalContent {
                return
            }

            Thread.sleep(forTimeInterval: max(pollInterval, 0.05))
        }

        throw NSError(
            domain: "MagicKit.FileAvailability",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Timed out waiting for iCloud file to download: \(lastPathComponent)"
            ]
        )
    }

    /// 计算文件的 MD5 哈希值。
    func getHash(verbose: Bool = false) -> String {
        guard !isFolder else {
            return ""
        }

        do {
            let handle = try FileHandle(forReadingFrom: self)
            defer { try? handle.close() }

            var hash = Insecure.MD5()
            while true {
                let data = handle.readData(ofLength: 1024)
                if data.isEmpty { break }
                hash.update(data: data)
            }

            return hash.finalize().map { String(format: "%02hhx", $0) }.joined()
        } catch {
            return ""
        }
    }

    /// 获取父目录 URL。
    func getParent() -> URL {
        deletingLastPathComponent()
    }

    /// 获取路径最后三个组件的简短显示。
    func shortPath() -> String {
        lastThreeComponents()
    }

    /// 获取路径的最后三个组件。
    func lastThreeComponents() -> String {
        pathComponents
            .filter { $0 != "/" }
            .suffix(3)
            .joined(separator: "/")
    }

    /// 在 Finder 中打开文件夹
    func openFolder() {
        guard URLOpenActionPolicy.canRevealInFinder(self) else { return }

        #if os(macOS)
            NSWorkspace.shared.activateFileViewerSelecting([self])
        #elseif os(iOS)
            UIApplication.shared.open(self)
        #endif
    }

    /// 在 Finder 中显示当前文件或目录。
    func openInFinder() {
        guard URLOpenActionPolicy.canRevealInFinder(self) else { return }

        #if os(macOS)
            NSWorkspace.shared.activateFileViewerSelecting([self])
        #elseif os(iOS)
            UIApplication.shared.open(self)
        #endif
    }

    /// 在系统默认应用中打开当前 URL。
    func open() {
        #if os(macOS)
            NSWorkspace.shared.open(self)
        #elseif os(iOS)
            UIApplication.shared.open(self)
        #endif
    }

    /// 获取文件大小的可读格式。
    func getSizeReadable() -> String {
        let size = getSize()
        guard size > 0 else {
            return "0 bytes"
        }

        if size < 1024 {
            return "\(size) bytes"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024.0)
        } else if size < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0))
        } else {
            return String(format: "%.1f GB", Double(size) / (1024.0 * 1024.0 * 1024.0))
        }
    }

    /// 计算文件或目录大小，单位为字节。
    func getSize() -> Int64 {
        if isFolder {
            return fileDescendants().reduce(Int64(0)) { total, url in
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return total + Int64(size)
            }
        }

        let size = (try? resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return Int64(size)
    }

    /// 创建一个打开当前 URL 的按钮。
    func makeOpenButton() -> some View {
        Group {
            if URLOpenActionPolicy.canOpen(self) {
                let accessibilityLabel = URLOpenActionPolicy.buttonAccessibilityLabel(for: self)

                Button(action: {
                    self.open()
                }) {
                    Label {
                        Text(accessibilityLabel)
                    } icon: {
                        Image(systemName: "folder")
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel)
                .help(accessibilityLabel)
            }
        }
    }

    /// 获取同级目录中的下一个文件。
    func getNextFile() -> URL? {
        let contents = deletingLastPathComponent().getChildren()
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard let index = contents.firstIndex(of: self) else { return nil }
        let nextIndex = index + 1
        return nextIndex < contents.count ? contents[nextIndex] : nil
    }

    /// 获取同级目录中的上一个文件。
    func getPrevFile() -> URL? {
        let contents = deletingLastPathComponent().getChildren()
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard let index = contents.firstIndex(of: self) else { return nil }
        return index > 0 ? contents[index - 1] : nil
    }

    /// 检查 URL 是否位于 iCloud Documents 容器中。
    func checkIsICloud(verbose: Bool = false) -> Bool {
        guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents") else {
            return false
        }

        return URLDirectoryContainmentPolicy.contains(path, inDirectory: iCloudURL.path)
    }

    /// Whether the URL is not under iCloud Documents.
    var isLocal: Bool {
        !checkIsICloud(verbose: false)
    }

    /// 检查 iCloud 文件是否正在下载。
    func checkIsDownloading(verbose: Bool = false) -> Bool {
        var mutableSelf = self
        mutableSelf.removeAllCachedResourceValues()

        guard let resources = try? mutableSelf.resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
            .ubiquitousItemIsDownloadingKey,
        ]) else {
            return false
        }

        guard resources.isUbiquitousItem == true else {
            return false
        }

        if resources.ubiquitousItemIsDownloading == true {
            return true
        }

        return resources.ubiquitousItemDownloadingStatus?.rawValue == "NSMetadataUbiquitousItemDownloadingStatusDownloading"
    }

    /// 获取 iCloud 文件当前下载进度，范围为 0...1。
    func getDownloadProgressSnapshot(verbose: Bool = false) -> Double {
        var mutableSelf = self
        mutableSelf.removeAllCachedResourceValues()

        if isLocal {
            return 1.0
        }

        let percentKey = URLResourceKey(rawValue: "NSURLUbiquitousItemPercentDownloadedKey")
        guard let resources = try? mutableSelf.resourceValues(forKeys: [
            .fileSizeKey,
            .fileAllocatedSizeKey,
            .ubiquitousItemDownloadingStatusKey,
            .ubiquitousItemIsDownloadingKey,
            percentKey,
        ]) else {
            return 0.0
        }

        if resources.ubiquitousItemDownloadingStatus == .current {
            return 1.0
        }

        let percentProgress = URLDownloadProgressPolicy.normalizedFraction(
            percentDownloaded: resources.allValues[percentKey] as? Double
        )
        if percentProgress > 0 {
            return percentProgress
        }

        return URLDownloadProgressPolicy.normalizedFraction(
            downloadedSize: resources.fileAllocatedSize,
            totalSize: resources.fileSize
        )
    }

    /// 将文件夹展开为所有非文件夹子项；普通文件返回自身。
    func flatten() -> [URL] {
        Array(fileDescendants())
    }

    private func fileDescendants() -> AnySequence<URL> {
        guard isFolder else { return AnySequence([self]) }

        guard let enumerator = FileManager.default.enumerator(
            at: self,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return AnySequence([])
        }

        return AnySequence {
            AnyIterator {
                while let url = enumerator.nextObject() as? URL {
                    if !url.isFolder {
                        return url
                    }
                }

                return nil
            }
        }
    }

    /// 获取文件夹内的直接子项。
    func getChildren() -> [URL] {
        guard isFolder else { return [] }

        return (try? FileManager.default.contentsOfDirectory(
            at: self,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    /// 递归统计当前 URL 下的文件数量。
    func filesCountRecursively() -> Int {
        guard FileManager.default.fileExists(atPath: path) else {
            return 0
        }

        guard isFolder else {
            return 1
        }

        return fileDescendants().reduce(0) { count, _ in count + 1 }
    }

    /// 获取本地图片缩略图。
    func thumbnailImage(
        size: CGSize = CGSize(width: 120, height: 120),
        useDefaultIcon: Bool = true,
        verbose: Bool,
        reason: String
    ) async throws -> Image? {
        #if os(macOS)
            if let image = NSImage(contentsOf: self) {
                return Image(nsImage: image)
            }
        #elseif os(iOS)
            if let image = UIImage(contentsOfFile: path) {
                return Image(uiImage: image)
            }
        #endif

        return useDefaultIcon ? Image(systemName: isFolder ? "folder" : "doc") : nil
    }

    /// 自动判断并监听文件夹变化。
    func onDirChange(
        verbose: Bool = false,
        caller: String,
        onChange: @escaping @Sendable (_ files: [URL], _ isInitialFetch: Bool, _ error: Error?) async -> Void,
        onDeleted: @escaping @Sendable (_ urls: [URL]) -> Void = { _ in },
        onProgress: @escaping @Sendable (_ url: URL, _ progress: Double) -> Void = { _, _ in }
    ) -> AnyCancellable {
        if checkIsICloud(verbose: false) {
            let monitor = ICloudDirectoryMonitor(
                directoryURL: self,
                verbose: verbose,
                caller: caller,
                onProgress: onProgress,
                onDeleted: onDeleted
            ) { files, isInitial, error in
                Task {
                    await onChange(files, isInitial, error)
                }
            }

            return monitor.start()
        }

        let monitor = LocalDirectoryMonitor(
            directoryURL: self,
            verbose: verbose,
            caller: caller,
            onChange: onChange
        )

        return monitor.start()
    }
}

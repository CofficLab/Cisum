import MagicKit
import LumiUI
import Foundation
import OSLog
import SwiftUI
import ProviderToast

/// 头像重建标识：URL + 缩略图重载次数。
///
/// iCloud 文件下载完成后内容才真正落到本地，此时必须让 `AvatarView` 重建并重新
/// 加载封面。把它作为 `.id(...)` 的值，是取代 kit 内部 `needsReload` 的机制。
struct AudioItemAvatarIdentity: Hashable {
    let id: URL
    let reloadToken: Int
}

enum AudioItemFileActionPolicy {
    static func canRevealInFinder(_ url: URL) -> Bool {
        pathExistsIncludingSymlink(url)
    }

    static func pathExistsIncludingSymlink(_ url: URL) -> Bool {
        if FileManager.default.fileExists(atPath: url.path) {
            return true
        }

        return (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }
}

/// 音频列表项视图组件
/// 用于在 AudioList 中展示单个音频文件
struct AudioItemView: View, Equatable, SuperLog {
    nonisolated static let emoji = "🎵"
    nonisolated static let verbose = false

    @ObservedObject var listViewModel: AudioListViewModel
    @Environment(\.toastProviding) private var toastProvider
    @LumiTheme private var appTheme

    let url: URL

    /// 删除确认对话框
    @State private var showDeleteConfirmation = false

    nonisolated static func == (lhs: AudioItemView, rhs: AudioItemView) -> Bool {
        lhs.url == rhs.url
    }

    /// 缩略图重载次数；直接读进度容器，绕过 `.equatable()` 的短路。
    private var reloadToken: Int {
        listViewModel.downloadStore.reloadToken(for: url)
    }

    init(_ url: URL, listViewModel: AudioListViewModel) {
        self.url = url
        self._listViewModel = ObservedObject(wrappedValue: listViewModel)
    }
}

// MARK: - View

extension AudioItemView {
    var body: some View {
        AppListRow(isSelected: listViewModel.selection == url, action: playAudio) {
            HStack(alignment: .center, spacing: 12) {
                // 头像部分：kit 内部下载监控已关闭（进度由插件状态源驱动），
                // 改由独立子视图叠加进度环。
                //
                // `.id(...)` 拼上缩略图重载标记：下载完成一次即换新 id，强制
                // AvatarView 重建并重新加载封面，取代 kit 内部 `needsReload`。
                url.makeAvatarView(verbose: Self.verbose)
                    .magicSize(.init(width: 40, height: 40))
                    .magicAvatarShape(.circle)
                    .magicBackground(appTheme.primary.opacity(0.1))
                    .magicDownloadMonitor(false)
                    .overlay {
                        AudioDownloadProgressRing(
                            store: listViewModel.downloadStore,
                            url: url,
                            backgroundColor: appTheme.primary.opacity(0.1)
                        )
                    }
                    // `.id(...)` 必须放在最后：它会把视图擦除为 `some View`，
                    // 放在链首会让后续 `magic*` 修饰符失去 `AvatarView` 类型。
                    .id(AudioItemAvatarIdentity(id: url, reloadToken: reloadToken))

                // 文件信息部分
                VStack(alignment: .leading, spacing: 4) {
                    Text(url.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                        .accessibilityIdentifier("cisum.audio-library.item.title")

                    HStack {
                        AudioItemFileSizeLabel(
                            url: url,
                            downloadStore: listViewModel.downloadStore
                        )
                    }
                }

                Spacer()
            }
        }
        #if os(macOS)
            .contextMenu {
                Button(action: playAudio) {
                    Label {
                        Text("Play", bundle: .module)
                    } icon: {
                        Image(systemName: "play.fill")
                    }
                }

                if AudioItemFileActionPolicy.canRevealInFinder(url) {
                    Button {
                        showInFinder()
                    } label: {
                        Label {
                            Text("Show in Finder", bundle: .module)
                        } icon: {
                            Image(systemName: "finder")
                        }
                    }
                }

                Button {
                    exportToDownloads()
                } label: {
                    Label {
                        Text("Export to Downloads", bundle: .module)
                    } icon: {
                        Image(systemName: "arrow.down.doc")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label {
                        Text("Delete", bundle: .module)
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
            }
        #endif
            .confirmationDialog(
                Text("Delete this file?", bundle: .module),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(role: .cancel) {} label: {
                    Text("Cancel", bundle: .module)
                }
                Button(role: .destructive) {
                    deleteFile()
                } label: {
                    Text("Delete", bundle: .module)
                }
            } message: {
                Text(url.lastPathComponent)
            }
    }
}

// MARK: - Action

extension AudioItemView {
    /// 导出到下载目录
    private func exportToDownloads() {
        let sourceURL = url
        Task {
            do {
                let finalDestinationURL = try await Task.detached(priority: .userInitiated) {
                    try await Self.copyToDownloads(sourceURL)
                }.value

                if Self.verbose {
                    os_log("\(Self.t)✅ File exported to: \(finalDestinationURL.path)")
                }
                toastProvider?.info(String(localized: "File copied to Downloads", bundle: .module))
            } catch {
                if Self.verbose {
                    os_log("\(Self.t)❌ Failed to export file: \(error.localizedDescription)")
                }
                toastProvider?.error(String(localized: "Export failed: \(error.localizedDescription)", bundle: .module))
            }
        }
    }

    nonisolated static func copyToDownloads(_ sourceURL: URL, downloadsURL: URL? = nil) async throws -> URL {
        // 获取下载目录
        let downloadsURL = try downloadsURL ?? FileManager.default.url(
            for: .downloadsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )

        try FileManager.default.createDirectory(at: downloadsURL, withIntermediateDirectories: true)

        let finalDestinationURL = uniqueDestination(for: sourceURL, in: downloadsURL)
        let sourceToCopy = copySourceURL(for: sourceURL)

        try await sourceToCopy.ensureLocalAvailability()

        try FileManager.default.copyItem(at: sourceToCopy, to: finalDestinationURL)
        return finalDestinationURL
    }

    nonisolated private static func copySourceURL(for sourceURL: URL) -> URL {
        let resolvedURL = sourceURL.resolvingSymlinksInPath().standardizedFileURL
        guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
            return sourceURL
        }

        return resolvedURL
    }

    nonisolated static func uniqueDestination(for sourceURL: URL, in directory: URL) -> URL {
        var destinationURL = directory.appendingPathComponent(sourceURL.lastPathComponent)
        var counter = 2

        while AudioItemFileActionPolicy.pathExistsIncludingSymlink(destinationURL) {
            let fileNameWithoutExtension = sourceURL.deletingPathExtension().lastPathComponent
            let fileExtension = sourceURL.pathExtension
            let newFileName = fileExtension.isEmpty
                ? "\(fileNameWithoutExtension) \(counter)"
                : "\(fileNameWithoutExtension) \(counter).\(fileExtension)"
            destinationURL = directory.appendingPathComponent(newFileName)
            counter += 1
        }

        return destinationURL
    }

    /// 播放音频
    private func playAudio() {
        if Self.verbose { os_log("\(Self.t)🖱️ Row action fired: \(url.lastPathComponent)") }
        Task {
            listViewModel.userSelected(url)
            if Self.verbose { os_log("\(Self.t)✅ Row action forwarded to AudioListViewModel: \(url.lastPathComponent)") }
        }
    }

    /// 在 Finder 中显示
    private func showInFinder() {
        #if os(macOS)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            if Self.verbose {
                os_log("\(Self.t)🔍 Showing in Finder: \(url.path)")
            }
        #endif
    }

    /// 删除文件（经 AudioListViewModel 委托，View 只发意图）。
    private func deleteFile() {
        listViewModel.deleteFile(url)
    }
}

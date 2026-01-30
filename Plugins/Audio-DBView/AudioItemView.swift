import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 音频列表项视图组件
/// 用于在 AudioList 中展示单个音频文件
struct AudioItemView: View, Equatable, SuperLog {
    nonisolated static let emoji = "🎵"
    nonisolated static let verbose = false

    @EnvironmentObject var m: MagicMessageProvider
    @EnvironmentObject var playMan: PlayMan

    let url: URL

    /// 文件大小显示文本
    @State private var sizeText: String = ""
    /// 删除确认对话框
    @State private var showDeleteConfirmation = false

    nonisolated static func == (lhs: AudioItemView, rhs: AudioItemView) -> Bool {
        lhs.url == rhs.url
    }

    init(_ url: URL) {
        self.url = url
    }
}

// MARK: - View

extension AudioItemView {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 头像部分
            url.makeAvatarView(verbose: Self.verbose)
                .magicSize(.init(width: 40, height: 40))
                .magicAvatarShape(.circle)
                .magicBackground(.blue.opacity(0.1))
                .magicDownloadMonitor(true)

            // 文件信息部分
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Text(sizeText.isEmpty ? "..." : sizeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .tag(url as URL?)
        .onAppear(perform: handleOnAppear)
        #if os(macOS)
            .contextMenu {
                Label("播放", systemImage: "play.fill")
                    .inButtonWithAction(playAudio)

                Label("在 Finder 中显示", systemImage: "finder")
                    .inButtonWithAction { showInFinder() }

                Label("导出到下载目录", systemImage: "arrow.down.doc")
                    .inButtonWithAction {
                        exportToDownloads()
                    }

                Divider()

                Button(role: .destructive, action: {
                    showDeleteConfirmation = true
                }) {
                    Label("删除", systemImage: "trash")
                }
            }
        #endif
            .confirmationDialog(
                "确定要删除这个文件吗？",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    deleteFile()
                }
            } message: {
                Text(url.lastPathComponent)
            }
    }
}

// MARK: - Event Handler

extension AudioItemView {
    /// 处理视图出现事件
    private func handleOnAppear() {
        Task {
            await loadFileSize()
        }
    }
}

// MARK: - Action

extension AudioItemView {
    /// 在后台加载文件大小
    private func loadFileSize() async {
        Task.detached(priority: .background) {
            let size = await Task.detached(priority: .background) {
                url.getSizeReadable()
            }.value

            await MainActor.run {
                sizeText = size
            }
        }
    }

    /// 导出到下载目录
    private func exportToDownloads() {
        Task {
            do {
                // 获取下载目录
                let downloadsURL = try FileManager.default.url(
                    for: .downloadsDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: false
                )

                // 目标文件路径
                let destinationURL = downloadsURL.appendingPathComponent(url.lastPathComponent)

                // 如果目标文件已存在，添加序号
                var finalDestinationURL = destinationURL
                var counter = 1
                while FileManager.default.fileExists(atPath: finalDestinationURL.path) {
                    let fileNameWithoutExtension = url.deletingPathExtension().lastPathComponent
                    let fileExtension = url.pathExtension
                    let newFileName = fileExtension.isEmpty
                        ? "\(fileNameWithoutExtension) \(counter)"
                        : "\(fileNameWithoutExtension) \(counter).\(fileExtension)"
                    finalDestinationURL = downloadsURL.appendingPathComponent(newFileName)
                    counter += 1
                }

                // 复制文件
                try await url.copyTo(finalDestinationURL, caller: self.className)
                if Self.verbose {
                    os_log("\(Self.t)✅ 文件已导出到: \(finalDestinationURL.path)")
                    self.m.info("文件已复制到下载目录")
                }
            } catch {
                if Self.verbose {
                    os_log("\(Self.t)❌ 导出文件失败: \(error.localizedDescription)")
                    self.m.error("导出文件失败: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 播放音频
    private func playAudio() {
        Task {
            await playMan.play(url, reason: "音频列表右键菜单")
            if Self.verbose {
                os_log("\(Self.t)▶️ 播放音频: \(url.lastPathComponent)")
            }
        }
    }

    /// 在 Finder 中显示
    private func showInFinder() {
        #if os(macOS)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            if Self.verbose {
                os_log("\(Self.t)🔍 在 Finder 中显示: \(url.path)")
            }
        #endif
    }

    /// 删除文件
    private func deleteFile() {
        Task {
            do {
                // 如果正在播放这个文件，先停止播放
                if playMan.currentURL == url {
                    await playMan.stop(reason: "删除文件")
                    if Self.verbose {
                        os_log("\(Self.t)⏹️ 停止播放当前文件")
                    }
                }

                // 删除文件
                try FileManager.default.removeItem(at: url)

                if Self.verbose {
                    os_log("\(Self.t)🗑️ 文件已删除: \(url.path)")
                }
                self.m.info("文件已删除")

                // 发送通知刷新列表
                NotificationCenter.default.post(
                    name: NSNotification.Name("AudioFilesDidChange"),
                    object: nil
                )
            } catch {
                if Self.verbose {
                    os_log("\(Self.t)❌ 删除文件失败: \(error.localizedDescription)")
                }
                self.m.error("删除文件失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

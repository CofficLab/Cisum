import MagicKit
import OSLog
import SwiftUI

/// 有声书设置视图：展示仓库大小、位置与文件数量。
struct BookSettings: View, SuperLog {
    nonisolated static let emoji = "🔊"

    @State var diskSize: String?
    @State var description: String = ""
    @State var fileCount: Int = 0
    @State var disk: URL? = nil

    var body: some View {
        Group {
            if let disk = disk {
                MagicSettingSection(title: "有声书仓库") {
                    MagicSettingRow(title: "仓库大小", description: description, icon: .iconMusicLibrary, content: {
                        HStack {
                            if let diskSize = diskSize {
                                Text(diskSize)
                                    .font(.footnote)
                            }
                        }

                    })

                    #if os(macOS)
                        MagicSettingRow(title: "打开仓库", description: "在Finder中查看", icon: .iconShowInFinder, content: {
                            HStack {
                                disk.makeOpenButton()
                            }

                        })
                    #endif

                    MagicSettingRow(title: "文件数量", description: "当前仓库内的文件总数", icon: .iconDocument, content: {
                        HStack {
                            Text("\(fileCount) 个文件")
                                .font(.footnote)
                        }
                    })
                }
            } else {
                MagicSettingSection(title: "歌曲仓库") {
                    MagicSettingRow(title: "出现错误", description: description, icon: .iconMusicLibrary, content: {
                        Text("暂时不能获取歌曲仓库信息")
                            .font(.footnote)
                    })
                }
            }
        }
        .task {
            self.updateDisk()
            self.updateDescription()
            self.updateFileCount()
            self.updateDiskSize()
        }
        .onStorageLocationChanged {
            self.updateDisk()
            self.updateDescription()
            self.updateFileCount()
            self.updateDiskSize()
        }
    }
}

// MARK: - Action

extension BookSettings {
    private func updateDiskSize() {
        guard let disk = self.disk else {
            return
        }

        self.diskSize = disk.getSizeReadable()
    }

    private func updateFileCount() {
        guard let disk = self.disk else {
            return
        }

        self.fileCount = disk.filesCountRecursively()
    }

    private func updateDisk() {
        self.disk = BookPlugin.getBookDisk()
    }

    private func updateDescription() {
        guard let disk = self.disk else {
            return
        }

        if disk.checkIsICloud(verbose: false) {
            description = "是 iCloud 云盘，会同步"
        } else {
            description = "是本地目录，不会同步"
        }
    }
}

// MARK: - Preview

#Preview("Setting") {
    RootView {
        SettingView()
            .background(.background)
    }
    .frame(height: 800)
}

#if os(macOS)
    #Preview("App - Large") {
        ContentView()
            .inRootView()
            .frame(width: 600, height: 1000)
    }

    #Preview("App - Small") {
        ContentView()
            .inRootView()
            .frame(width: 600, height: 600)
    }
#endif

#if os(iOS)
    #Preview("iPhone") {
        ContentView()
            .inRootView()
    }
#endif

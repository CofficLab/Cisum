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
                MagicSettingSection(title: "Audiobook Library") {
                    MagicSettingRow(title: "Library Size", description: description, icon: .iconMusicLibrary, content: {
                        HStack {
                            if let diskSize = diskSize {
                                Text(diskSize)
                                    .font(.footnote)
                            }
                        }

                    })

                    #if os(macOS)
                        MagicSettingRow(title: "Open Library", description: "View in Finder", icon: .iconShowInFinder, content: {
                            HStack {
                                disk.makeOpenButton()
                            }

                        })
                    #endif

                    MagicSettingRow(title: "File Count", description: "Total files in library", icon: .iconDocument, content: {
                        HStack {
                            Text("\(fileCount) files")
                                .font(.footnote)
                        }
                    })
                }
            } else {
                MagicSettingSection(title: "Music Library") {
                    MagicSettingRow(title: "Error", description: description, icon: .iconMusicLibrary, content: {
                        Text("Cannot get music library information")
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
            description = "iCloud Drive, will sync"
        } else {
            description = "Local directory, will not sync"
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

import MagicKit
import OSLog
import SwiftUI

/// 音频设置视图：展示仓库大小、位置与文件数量。
struct AudioSettings: View, SuperLog {
    nonisolated static let emoji = "🔊"

    @State var diskSize: String?
    @State var description: String = ""
    @State var fileCount: Int = 0
    @State var disk: URL? = nil

    var body: some View {
        Group {
            if let disk = disk {
                MagicSettingSection(title: "Music Library") {
                    MagicSettingRow(title: "Library Size", description: description, icon: .iconMusicLibrary, content: {
                        HStack {
                            if let diskSize = diskSize {
                                Text(diskSize)
                                    .font(.footnote)
                            }
                        }

                    })

                    MagicSettingRow(title: "Open Library", description: "View in Finder", icon: .iconShowInFinder, content: {
                        Image(systemName: .iconShowInFinder)
                            .frame(width: 28)
                            .frame(height: 28)
                            .background(.regularMaterial, in: .circle)
                            .shadowSm()
                            .hoverScale(105)
                            .inButtonWithAction {
                                disk.openInFinder()
                            }
                    })
                    .if(Config.isDesktop)

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

extension AudioSettings {
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
        self.disk = AudioPlugin.getAudioDisk()
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

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

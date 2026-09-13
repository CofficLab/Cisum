import CisumUIComponents
import OSLog
import SwiftUI

struct BookLibraryMetrics: Equatable {
    let diskSize: String
    let fileCount: Int
}

enum BookSettingsMetricsPolicy {
    static func shouldApplyMetrics(
        currentDisk: URL?,
        requestedDisk: URL,
        currentGeneration: Int,
        resultGeneration: Int
    ) -> Bool {
        currentDisk == requestedDisk && currentGeneration == resultGeneration
    }
}

enum BookSettingsFileCountTextPolicy {
    static func shouldUseSingular(_ count: Int) -> Bool {
        count == 1
    }
}

/// 有声书设置视图：展示仓库大小、位置与文件数量。
public struct BookSettingsView: View, SuperLog {
    public nonisolated static var emoji: String { BookSettingsPluginInfo.emoji }
    nonisolated static let openLibraryActionLabel = String(
        localized: "Open Library",
        bundle: .module
    )

    @ObservedObject private var viewModel: BookSettingsViewModel

    init(viewModel: BookSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        AppSettingsContentScaffold {
            VStack(alignment: .leading, spacing: 16) {
                if let disk = viewModel.disk {
                    AppSettingSection(title: String(localized: "Audiobook Library", bundle: .module)) {
                        AppSettingRow(
                            title: String(localized: "Library Size", bundle: .module),
                            description: viewModel.description,
                            icon: .cisumIconMusicLibrary
                        ) {
                            if let diskSize = viewModel.diskSize {
                                Text(diskSize)
                                    .font(.footnote)
                            }
                        }

                        #if os(macOS)
                            if Self.shouldShowOpenLibraryAction(for: disk) {
                                AppSettingRow(
                                    title: String(localized: "Open Library", bundle: .module),
                                    description: String(localized: "View in Finder", bundle: .module),
                                    icon: .cisumIconShowInFinder
                                ) {
                                    Image(systemName: .cisumIconShowInFinder)
                                        .frame(width: 28, height: 28)
                                        .background(.regularMaterial, in: Circle())
                                        .cisumShadowSm()
                                        .cisumHoverScale(105)
                                        .cisumButton {
                                            disk.openInFinder()
                                        }
                                        .accessibilityLabel(Self.openLibraryActionLabel)
                                        .help(Self.openLibraryActionLabel)
                                }
                            }
                        #endif

                        AppSettingRow(
                            title: String(localized: "File Count", bundle: .module),
                            description: String(localized: "Total files in library", bundle: .module),
                            icon: .cisumIconDocument
                        ) {
                            if Self.shouldUseSingularFileCount(viewModel.fileCount) {
                                Text("\(viewModel.fileCount) file", bundle: .module)
                                    .font(.footnote)
                            } else {
                                Text("\(viewModel.fileCount) files", bundle: .module)
                                    .font(.footnote)
                            }
                        }
                    }
                } else {
                    AppSettingSection(title: String(localized: "Audiobook Library", bundle: .module)) {
                        AppSettingRow(
                            title: String(localized: "Error", bundle: .module),
                            description: viewModel.description,
                            icon: .cisumIconMusicLibrary
                        ) {
                            Text("Cannot get audiobook library information", bundle: .module)
                                .font(.footnote)
                        }
                    }
                }
            }
        }
        .task {
            viewModel.refresh()
        }
        .onChange(of: viewModel.refreshToken) { _, _ in
            viewModel.refresh()
        }
    }
}
extension BookSettingsView {
    nonisolated static func shouldShowOpenLibraryAction(for disk: URL) -> Bool {
        URLOpenActionPolicy.canOpen(disk)
    }

    nonisolated static func shouldUseSingularFileCount(_ count: Int) -> Bool {
        BookSettingsFileCountTextPolicy.shouldUseSingular(count)
    }
}

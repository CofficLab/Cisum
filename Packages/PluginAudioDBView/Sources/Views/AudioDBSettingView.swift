import CisumUIComponents
import OSLog
import ProviderAudioLibrary
import SwiftUI
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// 音频仓库设置页：以两种方式展示仓库内容。
///
/// 通过 `AppSegmentedControl` 在两种展示模式间切换：
/// - 方式一（列表）：复用 `AudioListViewModel`，以列表形式展示音频库内容
///   （分页加载 + 总数统计）。
/// - 方式二（目录树）：复用 `AudioTreeViewModel`，以文件树形式展示仓库真实目录结构。
///
/// 右上角提供「打开仓库根目录」按钮，在 Finder 中打开音频仓库目录。
///
/// 布局统一使用 LumiUI 组件（`AppSettingsContentScaffold` /
/// `AppSettingSection` / `AppSettingRow` / `AppButton` / `AppEmptyState` /
/// `AppSegmentedControl` / `AppErrorBanner`）；仓库路径不可用时直接展示错误视图与完整诊断链路。
struct AudioDBSettingView: View, SuperLog {
    nonisolated static let emoji = "🎵"

    @ObservedObject var viewModel: AudioListViewModel
    @ObservedObject var treeViewModel: AudioTreeViewModel
    let deps: AudioDBDependencies
    @LumiTheme private var theme

    /// 展示模式：0 = 音频列表（方式一，默认），1 = 目录树（方式二）。
    @State private var displayMode = 0

    init(
        viewModel: AudioListViewModel,
        treeViewModel: AudioTreeViewModel,
        dependencies: AudioDBDependencies
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._treeViewModel = ObservedObject(wrappedValue: treeViewModel)
        self.deps = dependencies
    }

    var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            if deps.audioDisk() == nil {
                // 仓库路径拿不到：一切音频功能的基础缺失，直接展示错误视图。
                repositoryUnavailableView
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    repositoryPathSection

                    modeSwitcher

                    content
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(theme.divider, lineWidth: 1)
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .onAppear {
            viewModel.handleOnAppear()
        }
        .onChange(of: displayMode) { _, newValue in
            if newValue == 1 {
                treeViewModel.handleOnAppear()
            }
        }
    }

    // MARK: - 展示模式切换（方式一：列表 / 方式二：目录树）

    /// 方式一/方式二切换控件：两种模式共用同一内容容器与统计头部。
    private var modeSwitcher: some View {
        AppSegmentedControl(
            [
                String(localized: "List", bundle: .module),
                String(localized: "Directory tree", bundle: .module),
            ],
            selection: $displayMode,
            maxWidth: 280
        )
    }

    /// 当前展示模式下的内容区。
    @ViewBuilder
    private var content: some View {
        if displayMode == 0 {
            list
        } else {
            AudioTreeView(viewModel: treeViewModel)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Spacer()
            Text("Total \(viewModel.totalCount.description)", bundle: .module)
                .font(.appCaption)
                .foregroundStyle(.secondary)
            #if os(macOS)
            openDirectoryButton
            #endif
        }
    }

    // MARK: - 仓库路径（LumiUI 设置卡片）

    /// 以 LumiUI 设置卡片展示音频仓库根目录路径（与「打开仓库根目录」按钮共用
    /// 注入的 `audioDisk`），路径可选中复制；仓库不可用时显示占位文案。
    @MainActor
    private var repositoryPathSection: some View {
        let disk = deps.audioDisk()
        return AppSettingSection(title: String(localized: "Repository Path", bundle: .module)) {
            AppSettingRow(
                title: String(localized: "Repository path", bundle: .module),
                description: String(localized: "The root directory that stores all audio files", bundle: .module),
                icon: "folder"
            ) {
                if let disk {
                    Text(disk.path(percentEncoded: false))
                        .font(.appCaption)
                        .foregroundStyle(theme.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .help(Text(disk.path(percentEncoded: false)))
                } else {
                    Text("Unavailable", bundle: .module)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - 错误视图（仓库路径不可用）

    /// 仓库路径无法解析时的错误视图。
    ///
    /// 仓库路径是一切音频功能的基础，拿不到时不再展示空列表，而是直接给出
    /// 错误说明 + 完整诊断链路（LumiUI 组件），方便开发者/用户定位根因。
    @MainActor
    private var repositoryUnavailableView: some View {
        let diagnostics = deps.audioDiagnostics()
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(theme.error)
                    Text("Audio repository is unavailable", bundle: .module)
                        .font(.appTitle)
                }

                Text(
                    "The repository path is the foundation of all audio features. It could not be resolved. Check the storage settings, or review the diagnostics below and include them when reporting an issue.",
                    bundle: .module
                )
                .font(.appBody)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                if let reason = diagnostics.failureReason {
                    AppErrorBanner(message: LocalizedStringKey(reason))
                }

                AppSettingSection(title: String(localized: "Diagnostics", bundle: .module)) {
                    VStack(spacing: 0) {
                        diagnosticRow(
                            label: String(localized: "Storage location", bundle: .module),
                            value: diagnostics.storageLocationRaw ?? "nil"
                        )
                        Divider()
                        diagnosticRow(
                            label: String(localized: "Usable storage location", bundle: .module),
                            value: String(diagnostics.hasUsableStorageLocation)
                        )
                        Divider()
                        diagnosticRow(
                            label: String(localized: "iCloud available", bundle: .module),
                            value: String(diagnostics.isICloudAvailable)
                        )
                        Divider()
                        diagnosticRow(
                            label: String(localized: "iCloud container", bundle: .module),
                            value: diagnostics.cloudContainer ?? "nil"
                        )
                        Divider()
                        diagnosticRow(
                            label: String(localized: "iCloud Documents", bundle: .module),
                            value: diagnostics.cloudDocuments ?? "nil"
                        )
                        Divider()
                        diagnosticRow(
                            label: String(localized: "Local Documents", bundle: .module),
                            value: diagnostics.localDocuments ?? "nil"
                        )
                        Divider()
                        diagnosticRow(
                            label: String(localized: "Storage root", bundle: .module),
                            value: diagnostics.storageRoot ?? "nil"
                        )
                        Divider()
                        diagnosticRow(
                            label: String(localized: "Audio repository path", bundle: .module),
                            value: diagnostics.audioDisk ?? "nil"
                        )
                        Divider()
                        diagnosticRow(
                            label: String(localized: "Repository directory name", bundle: .module),
                            value: diagnostics.dbDirName
                        )

                        HStack {
                            Spacer()
                            AppButton(
                                String(localized: "Copy diagnostics", bundle: .module),
                                systemImage: "doc.on.doc",
                                style: .secondary,
                                size: .small
                            ) {
                                copyToPasteboard(diagnostics.summary)
                            }
                            .help(Text("Copy diagnostics", bundle: .module))
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(2)
        }
    }

    /// 诊断面板行：左侧标签，右侧等宽可选中值。
    private func diagnosticRow(label: String, value: String) -> some View {
        AppSettingRow(title: label) {
            Text(value)
                .font(.appCaption)
                .fontDesign(.monospaced)
                .lineLimit(4)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }

    private func copyToPasteboard(_ text: String) {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        #else
            UIPasteboard.general.string = text
        #endif
    }

    // MARK: - 打开仓库根目录

    #if os(macOS)
    /// 打开音频仓库根目录（Finder 中显示该文件夹）；仓库目录不可用时按钮置灰。
    @MainActor
    private var openDirectoryButton: some View {
        let disk = deps.audioDisk()
        return AppButton(
            String(localized: "Open repository folder", bundle: .module),
            systemImage: "folder",
            style: .secondary,
            size: .small
        ) {
            disk?.openFolder()
        }
        .disabled(disk == nil)
        .help(Text("Open repository folder", bundle: .module))
    }
    #endif

    // MARK: - 仓库内容列表

    private var list: some View {
        List {
            if viewModel.isLoading && viewModel.urls.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if viewModel.urls.isEmpty && !viewModel.isLoading {
                AppEmptyState(
                    icon: "music.note",
                    title: String(localized: "Music repository is empty", bundle: .module)
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(Array(viewModel.urls.enumerated()), id: \.element) { index, url in
                    row(url: url)
                        .listRowBackground(Color.clear)
                        .onAppear {
                            // 接近阈值时预取下一页（对齐 AudioList 行为）。
                            if AudioListLoadPolicy.isNearThreshold(
                                currentIndex: index,
                                loadedCount: viewModel.urls.count
                            ) {
                                viewModel.checkLoadMore(at: index)
                            }
                        }
                }
            }

            if viewModel.isLoadingMore && !viewModel.urls.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
    }

    private func row(url: URL) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "music.note")
                .foregroundStyle(theme.primary)
                .frame(width: 18)
            Text(url.deletingPathExtension().lastPathComponent)
                .lineLimit(1)
            Spacer()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            os_log("\(Self.t)🖱️ Settings repository row tapped (view-only; no playback action): \(url.path)")
        }
    }
}

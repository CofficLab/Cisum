import CisumUIComponents
import ProviderBook
import ProviderBook
import SwiftUI

/// 有声书仓库设置页：以两种方式展示仓库内容。
///
/// 通过 `AppSegmentedControl` 在两种展示模式间切换：
/// - 方式一（列表）：复用 `BookListViewModel`，以列表形式展示有声书仓库内容
///   （书籍标题 + 子章节数 + 总数统计）。
/// - 方式二（目录树）：复用 `BookTreeViewModel`，以文件树形式展示仓库真实目录结构。
///
/// 右上角提供「打开仓库根目录」按钮，在 Finder 中打开有声书仓库目录。
///
/// 布局统一使用 LumiUI 组件（`AppSettingsContentScaffold` /
/// `AppSettingSection` / `AppSettingRow` / `AppButton` / `AppEmptyState` /
/// `AppSegmentedControl`）。
struct BookDBSettingView: View {
    @ObservedObject var viewModel: BookListViewModel
    @ObservedObject var treeViewModel: BookTreeViewModel
    let deps: BookDBDependencies
    @LumiTheme private var theme

    /// 展示模式：0 = 书籍列表（方式一，默认），1 = 目录树（方式二）。
    @State private var displayMode = 0

    init(
        viewModel: BookListViewModel,
        treeViewModel: BookTreeViewModel,
        dependencies: BookDBDependencies
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._treeViewModel = ObservedObject(wrappedValue: treeViewModel)
        self.deps = dependencies
    }

    var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
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
            BookTreeView(viewModel: treeViewModel)
        }
    }

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

    /// 以 LumiUI 设置卡片展示有声书仓库根目录路径（与「打开仓库根目录」按钮共用
    /// 注入的 `bookDisk`），路径可选中复制；仓库不可用时显示占位文案。
    @MainActor
    private var repositoryPathSection: some View {
        let disk = deps.bookDisk()
        return AppSettingSection(title: String(localized: "Repository Path", bundle: .module)) {
            AppSettingRow(
                title: String(localized: "Repository path", bundle: .module),
                description: String(localized: "The root directory that stores all audiobook files", bundle: .module),
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

    // MARK: - 打开仓库根目录

    #if os(macOS)
    /// 打开有声书仓库根目录（Finder 中显示该文件夹）；仓库目录不可用时按钮置灰。
    @MainActor
    private var openDirectoryButton: some View {
        let disk = deps.bookDisk()
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

    private var list: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if viewModel.books.isEmpty {
                AppEmptyState(
                    icon: "book.closed",
                    title: String(localized: "Audiobook repository is empty", bundle: .module)
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.books) { book in
                    row(book: book)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
    }

    private func row(book: BookDTO) -> some View {
        HStack(spacing: 10) {
            Image(systemName: BookDBViewPluginInfo.iconName)
                .foregroundStyle(theme.primary)
                .frame(width: 18)
            Text(book.bookTitle)
                .lineLimit(1)
            Spacer()
            if book.childCount > 0 {
                Text(book.childCount.description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

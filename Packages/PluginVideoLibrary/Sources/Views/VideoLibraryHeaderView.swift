import LumiUI
import ProviderVideo
import SwiftUI

/// 资料库页头：导航位置、标题与摘要、搜索、排序、显示方式、导入。
struct VideoLibraryHeaderView: View {
    @ObservedObject var viewModel: VideoLibraryViewModel
    let layout: VideoLibraryLayout
    let onToggleSidebar: () -> Void
    let onImport: () -> Void

    var body: some View {
        Group {
            if layout == .compact {
                VStack(alignment: .leading, spacing: 8) {
                    breadcrumb
                    titleBlock
                    controls
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    breadcrumb
                    HStack(alignment: .bottom, spacing: 12) {
                        titleBlock
                        Spacer(minLength: 8)
                        controls
                    }
                }
            }
        }
        .padding(.horizontal, layout == .compact ? 12 : 16)
        .padding(.vertical, 12)
    }

    // MARK: - Sections

    private var breadcrumb: some View {
        HStack(spacing: 5) {
            if layout == .compact {
                Button(action: onToggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "Sidebar", bundle: .module))
                .accessibilityIdentifier("cisum.video.sidebar.toggle")
            }

            Text(String(localized: "Video Library", bundle: .module))
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
            Text(String(localized: String.LocalizationValue(viewModel.scope.title), bundle: .module))

            if viewModel.repositoryState.isWorking {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: String.LocalizationValue(viewModel.navigationTitle), bundle: .module))
                .font(layout == .compact ? .title2 : .title)
                .bold()
                .lineLimit(1)
            Text(summaryTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("cisum.video.summary")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cisum.video.title")
    }

    private var summaryTitle: String {
        String(
            format: String(localized: "%lld videos · %@", bundle: .module),
            Int64(viewModel.filteredItems.count),
            viewModel.totalSizeTitle
        )
    }

    private var controls: some View {
        HStack(spacing: 8) {
            #if !os(iOS)
            AppSearchBar(text: $viewModel.searchText, placeholder: "Search")
                .frame(maxWidth: 220)
                .accessibilityIdentifier("cisum.video.search")
            #endif

            if layout == .compact {
                scopeMenu
            }

            sortMenu
            displayModePicker
            importButton
        }
        .controlSize(.small)
    }

    private var sortMenu: some View {
        Menu {
            Picker("", selection: $viewModel.sortOrder) {
                ForEach(VideoSortOrder.allCases, id: \.self) { order in
                    Label(String(localized: String.LocalizationValue(order.title), bundle: .module), systemImage: order.systemImage)
                        .tag(order)
                }
            }
            .labelsHidden()
            .pickerStyle(.inline)
        } label: {
            touchTarget(Image(systemName: "arrow.up.arrow.down"))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .accessibilityLabel(String(localized: String.LocalizationValue(viewModel.sortOrder.title), bundle: .module))
        .accessibilityIdentifier("cisum.video.sort")
    }

    private var displayModePicker: some View {
        Picker("", selection: $viewModel.displayMode) {
            ForEach(VideoLibraryDisplayMode.allCases, id: \.self) { mode in
                Image(systemName: mode.systemImage)
                    .tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .fixedSize()
        .accessibilityIdentifier("cisum.video.displaymode")
    }

    private var importButton: some View {
        Button(action: onImport) {
            if layout == .compact {
                touchTarget(Image(systemName: "square.and.arrow.down"))
            } else {
                touchTarget(Label(String(localized: "Import", bundle: .module), systemImage: "plus"))
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.repositoryURL == nil)
        .accessibilityLabel(String(localized: "Import Videos", bundle: .module))
        .accessibilityIdentifier("cisum.video.import")
    }

    /// 窄布局的范围 / 标签菜单（宽布局由侧栏承担）。
    private var scopeMenu: some View {
        Menu {
            ForEach(VideoSidebarView.scopeOrder, id: \.self) { scope in
                Button {
                    viewModel.select(scope)
                } label: {
                    Label {
                        Text("\(String(localized: String.LocalizationValue(scope.title), bundle: .module)) \(viewModel.count(for: scope))")
                    } icon: {
                        Image(systemName: viewModel.scope == scope && viewModel.selectedFolder == nil
                            ? "checkmark" : scope.systemImage)
                    }
                }
                .accessibilityIdentifier("cisum.video.scope.\(scope.rawValue)")
            }

            if !viewModel.allTags.isEmpty {
                Divider()
                ForEach(viewModel.allTags, id: \.self) { tag in
                    Button {
                        viewModel.selectedTag = viewModel.selectedTag == tag ? nil : tag
                    } label: {
                        Label(tag, systemImage: viewModel.selectedTag == tag ? "checkmark" : "tag")
                    }
                }
            }

            if viewModel.hasActiveFilters {
                Divider()
                Button(String(localized: "Clear Filters", bundle: .module)) {
                    viewModel.clearFilters()
                }
            }
        } label: {
            touchTarget(Image(systemName: viewModel.hasActiveFilters
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle"))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .accessibilityLabel(String(localized: String.LocalizationValue(viewModel.scope.title), bundle: .module))
        .accessibilityIdentifier("cisum.video.filters")
    }

    /// 触控平台保证最小点击区域。
    private func touchTarget<Image: View>(_ image: Image) -> some View {
        #if os(iOS) || os(visionOS)
        return image.frame(width: 44, height: 44)
        #else
        return image.frame(width: 28, height: 24)
        #endif
    }
}

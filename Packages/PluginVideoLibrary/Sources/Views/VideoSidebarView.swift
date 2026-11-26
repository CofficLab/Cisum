import ProviderVideo
import SwiftUI

/// 资料库侧栏：智能分组、文件夹、标签与存储卡片。
struct VideoSidebarView: View {
    /// 侧栏与窄布局菜单共用的范围顺序。
    static let scopeOrder: [VideoLibraryScope] = [.all, .continueWatching, .recentlyAdded, .favorites, .undownloaded]

    @ObservedObject var viewModel: VideoLibraryViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    sectionLabel(String(localized: "Library", bundle: .module))
                    ForEach(Self.scopeOrder, id: \.self) { scope in
                        scopeRow(scope)
                    }

                    if !viewModel.folders.isEmpty {
                        sectionLabel(String(localized: "Folders", bundle: .module))
                        ForEach(viewModel.folders) { folder in
                            folderRow(folder)
                        }
                    }

                    if !viewModel.allTags.isEmpty {
                        sectionLabel(String(localized: "Tags", bundle: .module))
                        VideoWrapLayout {
                            ForEach(viewModel.allTags, id: \.self) { tag in
                                tagChip(tag)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.vertical, 10)
            }
            Divider()
            storageCard
        }
        .background(Color.primary.opacity(0.03))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cisum.video.sidebar")
    }

    // MARK: - Rows

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 3)
    }

    private func scopeRow(_ scope: VideoLibraryScope) -> some View {
        let isActive = viewModel.scope == scope && viewModel.selectedFolder == nil
        return Button {
            viewModel.select(scope)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: scope.systemImage)
                    .frame(width: 16)
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                Text(String(localized: String.LocalizationValue(scope.title), bundle: .module))
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
                Spacer()
                Text("\(viewModel.count(for: scope))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isActive ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cisum.video.scope.\(scope.rawValue)")
    }

    private func folderRow(_ folder: VideoFolder) -> some View {
        let isActive = viewModel.selectedFolder == folder.path
        return Button {
            viewModel.select(folder: folder)
        } label: {
            HStack(spacing: 8) {
                Color.clear
                    .frame(width: CGFloat(min(folder.depth - 1, 3)) * 12, height: 1)
                Image(systemName: folder.isRoot ? "folder" : "folder")
                    .frame(width: 16)
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                Text(folder.isRoot ? String(localized: "Uncategorized", bundle: .module) : folder.name)
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
                    .lineLimit(1)
                Spacer()
                Text("\(viewModel.count(in: folder))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isActive ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cisum.video.folder.\(folder.isRoot ? "root" : folder.path)")
    }

    private func tagChip(_ tag: String) -> some View {
        let isActive = viewModel.selectedTag == tag
        return Button {
            viewModel.selectedTag = isActive ? nil : tag
        } label: {
            Text("#\(tag)")
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    isActive ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06),
                    in: Capsule()
                )
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cisum.video.tag.\(tag)")
    }

    // MARK: - Storage

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: isCloud ? "icloud" : "internaldrive")
                    .foregroundStyle(.secondary)
                Text(locationTitle)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Spacer()
                #if os(macOS)
                if let url = viewModel.repositoryURL {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(String(localized: "Show in Finder", bundle: .module))
                    .accessibilityIdentifier("cisum.video.reveal")
                }
                #endif
                Button {
                    viewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "Rescan", bundle: .module))
                .accessibilityIdentifier("cisum.video.rescan")
                .disabled(viewModel.repositoryURL == nil)
            }

            Text(storageMeta)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        .padding(8)
    }

    private var isCloud: Bool {
        viewModel.storageLocationTitle == "iCloud"
    }

    private var locationTitle: String {
        let title = viewModel.storageLocationTitle
        return title.isEmpty
            ? String(localized: "No Repository", bundle: .module)
            : String(localized: String.LocalizationValue(title), bundle: .module)
    }

    private var storageMeta: String {
        guard viewModel.repositoryURL != nil else {
            return String(localized: "No Repository", bundle: .module)
        }
        let summary = String(
            format: String(localized: "%lld videos · %@", bundle: .module),
            Int64(viewModel.items.count),
            viewModel.librarySizeTitle
        )
        guard viewModel.repositoryState.isWorking else { return summary }
        let state = String(localized: String.LocalizationValue(viewModel.repositoryState.title), bundle: .module)
        return "\(summary) · \(state)"
    }
}

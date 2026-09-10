import CisumUIComponents
import SwiftUI

/// 有声书仓库目录树视图（设置页「目录树」模式）。
///
/// 以文件树形式展示仓库真实目录结构：目录节点可展开/收起，
/// 文件节点仅收录受支持的有声书扩展名。目录右侧显示子项数量。
struct BookTreeView: View {
    @EnvironmentObject var viewModel: BookTreeViewModel
    @LumiTheme private var theme

    var body: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if viewModel.children.isEmpty {
                AppEmptyState(
                    icon: "folder",
                    title: String(localized: "Directory tree is empty", bundle: .module)
                )
                .listRowBackground(Color.clear)
            } else {
                OutlineGroup(viewModel.children, children: \.children) { node in
                    row(node: node)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
    }

    private func row(node: BookTreeNode) -> some View {
        HStack(spacing: 10) {
            Image(systemName: node.isDirectory ? "folder" : "music.note")
                .foregroundStyle(node.isDirectory ? theme.primary : theme.textSecondary)
                .frame(width: 18)
            Text(node.name)
                .lineLimit(1)
            Spacer()
            if node.isDirectory, node.childCount > 0 {
                Text(node.childCount.description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

import Foundation
import ProviderAudioLibrary

/// 音频仓库目录树节点（设置页「目录树」模式专用）。
///
/// 以文件系统真实目录结构构建：目录节点递归包含子节点，文件节点仅收录
/// 受支持的音乐扩展名（`AudioPluginInfo.supportedExtensions`）；隐藏文件
/// （如 `.DS_Store`、`.hidden.mp3`）不参与构建。
///
/// `children` 为可选：目录为子节点数组（可能为空），文件为 `nil`，
/// 以适配 `OutlineGroup` 的 `children` KeyPath（指向可选集合）。
struct AudioTreeNode: Identifiable, Equatable, Sendable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let children: [AudioTreeNode]?

    var id: URL { url }

    /// 子节点数量（目录 = 子节点总数，文件 = 0）。
    var childCount: Int { children?.count ?? 0 }

    /// 是否可展开（目录且含子节点）。
    var isExpandable: Bool { isDirectory && !(children?.isEmpty ?? true) }
}

/// 目录树构建器：从磁盘递归扫描音频仓库目录。
///
/// 纯函数式构建，可在后台线程执行；结果按「目录优先、名称本地化排序」
/// 排列，与主内容区（`AudioList` / `AudioRepo`）的展示顺序对齐。
enum AudioTreeBuilder {
    /// 构建仓库根目录下的第一级节点（不含根目录本身）。
    ///
    /// 根目录路径已由设置页的「仓库路径」卡片展示，目录树直接呈现其内部结构。
    static func buildRootChildren(from root: URL) -> [AudioTreeNode] {
        buildChildren(of: root)
    }

    /// 是否受支持的音乐文件（按扩展名判断，忽略大小写）。
    static func isSupportedAudioFile(_ url: URL) -> Bool {
        AudioPluginInfo.supportedExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: - Recursive scan

    private static func buildChildren(of directory: URL) -> [AudioTreeNode] {
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var folders: [AudioTreeNode] = []
        var files: [AudioTreeNode] = []

        for url in urls {
            if url.isFolder {
                let children = buildChildren(of: url)
                folders.append(
                    AudioTreeNode(
                        url: url,
                        name: url.lastPathComponent,
                        isDirectory: true,
                        children: children
                    )
                )
            } else if isSupportedAudioFile(url) {
                files.append(
                    AudioTreeNode(
                        url: url,
                        name: url.lastPathComponent,
                        isDirectory: false,
                        children: nil
                    )
                )
            }
        }

        folders.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        files.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        return folders + files
    }
}

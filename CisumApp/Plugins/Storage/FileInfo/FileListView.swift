import MagicKit

import OSLog
import SwiftUI

struct FileListView: View, SuperLog {
    nonisolated static let emoji = "📂"

    let url: URL
    let expandByDefault: Bool

    @State private var selection = Set<FileItem>()
    @State private var expandedItems = Set<FileItem>()
    @State private var visibleItems: [FileItem] = []
    @State private var itemCache: [URL: [FileItem]] = [:]

    // 添加忽略文件列表
    private let ignoredFiles = [
        ".DS_Store",
        ".git",
        ".svn",
        "__pycache__",
        "node_modules"
    ]

    init(url: URL, expandByDefault: Bool = false) {
        self.url = url
        self.expandByDefault = expandByDefault

        // 创建根目录项
        let rootItem = FileItem(url: url, level: 0, isExpanded: expandByDefault)

        // 设置初始可见项
        _visibleItems = State(initialValue: [rootItem])

        if expandByDefault {
            _expandedItems = State(initialValue: [rootItem])
        }
    }

    var body: some View {
        Table(of: FileItem.self) {
            TableColumn("名称") { item in
                HStack(spacing: 0) {
                    // 缩进
                    ForEach(0 ..< item.level, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 1)
                            .padding(.horizontal, 8)
                    }

                    // 展开/折叠按钮 + 文件图标 + 名称
                    HStack(spacing: 4) {
                        FileExpandButton(
                            isDirectory: (try? item.url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false,
                            initialExpanded: item.isExpanded
                        ) { isExpanded in
                            toggleExpanded(item)
                        }

                        FileTitleView(url: item.url)
                    }
                }
            }
            .width(min: 200)

            TableColumn("大小") { item in
                FileSizeView(url: item.url)
            }
            .width(80)

            TableColumn("状态") { item in
                FileStatusColumnView(url: item.url)
            }
            .width(200)
        } rows: {
            ForEach(visibleItems) { item in
                TableRow(item)
            }
        }
        .font(.system(size: 13))
        .task(priority: .background) {
            if expandByDefault {
                updateVisibleItems(reason: "onAppear")
            }
        }
    }

    private func cacheChildItems(for item: FileItem) {
        guard let children = item.children() else { return }
        
        // 过滤掉需要忽略的文件，并按名称排序
        let filteredChildren = children
            .filter { child in
                !ignoredFiles.contains(child.url.lastPathComponent)
            }
            .sorted { item1, item2 in
                item1.url.lastPathComponent.localizedStandardCompare(item2.url.lastPathComponent) == .orderedAscending
            }
        
        var newCache = self.itemCache
        newCache[item.url] = filteredChildren
        self.setItemCache(newCache)

        // 递归缓存子文件夹的内容
        for child in filteredChildren {
            if (try? child.url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                self.cacheChildItems(for: child)
            }
        }
    }

    private func toggleExpanded(_ item: FileItem) {
        if expandedItems.contains(item) {
            expandedItems.remove(item)
        } else {
            expandedItems.insert(item)
        }

        updateVisibleItems(reason: "toggleExpanded")
    }

    private func addItemsRecursively(from item: FileItem, into result: inout [FileItem]) {
        if let cachedChildren = itemCache[item.url] {
            for child in cachedChildren {
                let isExpanded = expandedItems.contains { $0.url == child.url }
                let childItem = FileItem(url: child.url, level: child.level, isExpanded: isExpanded)
                result.append(childItem)

                if childItem.isExpanded {
                    addItemsRecursively(from: childItem, into: &result)
                }
            }
        }
    }

    private func updateVisibleItems(reason: String) {
        Task.detached(priority: .high, operation: {
            os_log("\(self.t)🔄 Updating visible items with reason: \(reason)")

            await cacheChildItems(for: FileItem(url: url, level: 0, isExpanded: true))

            var result: [FileItem] = []

            let rootItem = await FileItem(url: url, level: 0, isExpanded: expandedItems.contains { $0.url == url })
            result.append(rootItem)

            if rootItem.isExpanded {
                await addItemsRecursively(from: rootItem, into: &result)
            }

            await setVisibleItems(result)
        })
    }

    @MainActor
    private func setVisibleItems(_ items: [FileItem]) {
        visibleItems = items
    }

    @MainActor
    private func setItemCache(_ cache: [URL: [FileItem]]) {
        itemCache = cache
    }
}

#Preview("文件列表") {
    let url = URL(filePath: "/Users/user/Music")

    return FileListView(url: url, expandByDefault: true)
        .frame(height: 400)
        .padding()
}

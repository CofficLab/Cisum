import MagicKit
import CisumUIComponents
import LumiUI

import OSLog
import SwiftUI

enum FileListUpdatePolicy {
    static func shouldApplyResult(currentGeneration: Int, resultGeneration: Int) -> Bool {
        currentGeneration == resultGeneration
    }
}

struct FileListView: View, SuperLog {
    nonisolated static let emoji = "📂"

    let url: URL
    let expandByDefault: Bool

    @State private var selection = Set<FileItem>()
    @State private var expandedItems = Set<FileItem>()
    @State private var visibleItems: [FileItem] = []
    @State private var itemCache: [URL: [FileItem]] = [:]
    @State private var loadErrorMessage: String?
    @State private var updateGeneration = 0

    nonisolated private static let ignoredFiles = [
        ".DS_Store",
        ".git",
        ".svn",
        "__pycache__",
        "node_modules"
    ]

    init(url: URL, expandByDefault: Bool = false) {
        self.url = url
        self.expandByDefault = expandByDefault

        let state = Self.initialState(rootURL: url, expandByDefault: expandByDefault)
        _visibleItems = State(initialValue: state.visibleItems)
        _expandedItems = State(initialValue: state.expandedItems)
    }

    var body: some View {
        ZStack {
            Table(of: FileItem.self) {
                TableColumn(String(localized: "Name", bundle: .module)) { item in
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
                                isExpanded: expandedItems.contains(item)
                            ) { isExpanded in
                                setExpanded(isExpanded, for: item)
                            }

                            FileTitleView(url: item.url)
                        }
                    }
                }
                .width(min: 200)

                TableColumn(String(localized: "Size", bundle: .module)) { item in
                    FileSizeView(url: item.url)
                }
                .width(80)

                TableColumn(String(localized: "Status", bundle: .module)) { item in
                    FileStatusColumnView(url: item.url)
                }
                .width(200)
            } rows: {
                ForEach(visibleItems) { item in
                    TableRow(item)
                }
            }
            .font(.system(size: 13))

            if let loadErrorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text("Unable to read file list", bundle: .module)
                        .font(.headline)
                    Text(loadErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .padding()
                .frame(maxWidth: 320)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .task(priority: .background) {
            if expandByDefault {
                updateVisibleItems(reason: "onAppear")
            }
        }
        .onChange(of: url) { _, newURL in
            resetRoot(to: newURL)
        }
    }

    private func resetRoot(to newURL: URL) {
        updateGeneration += 1
        let state = Self.initialState(rootURL: newURL, expandByDefault: expandByDefault)
        selection.removeAll()
        expandedItems = state.expandedItems
        visibleItems = state.visibleItems
        itemCache.removeAll()
        loadErrorMessage = nil

        if expandByDefault {
            updateVisibleItems(reason: "rootChanged")
        }
    }

    nonisolated static func initialState(
        rootURL: URL,
        expandByDefault: Bool
    ) -> (visibleItems: [FileItem], expandedItems: Set<FileItem>) {
        let rootItem = FileItem(url: rootURL, level: 0, isExpanded: expandByDefault)
        let expandedItems: Set<FileItem> = expandByDefault ? [rootItem] : []
        return ([rootItem], expandedItems)
    }

    private func setExpanded(_ isExpanded: Bool, for item: FileItem) {
        if isExpanded {
            expandedItems.insert(item)
        } else {
            expandedItems.remove(item)
        }
        itemCache = Self.cacheAfterExpansionChange(
            isExpanded: isExpanded,
            itemURL: item.url,
            currentCache: itemCache
        )

        updateVisibleItems(reason: "toggleExpanded")
    }

    nonisolated static func cacheAfterExpansionChange(
        isExpanded: Bool,
        itemURL: URL,
        currentCache: [URL: [FileItem]]
    ) -> [URL: [FileItem]] {
        guard isExpanded else { return currentCache }

        var updatedCache = currentCache
        updatedCache.removeValue(forKey: itemURL)
        return updatedCache
    }

    private func updateVisibleItems(reason: String) {
        updateGeneration += 1
        let generation = updateGeneration
        let rootURL = url
        let expandedURLs = Set(expandedItems.map(\.url))
        let cachedItems = itemCache

        Task.detached(priority: .high, operation: {
            os_log("\(Self.t)🔄 Updating visible items with reason: \(reason)")

            let update = Self.buildVisibleItems(
                rootURL: rootURL,
                expandedURLs: expandedURLs,
                cachedItems: cachedItems
            )

            await applyVisibleItemsUpdate(
                update,
                generation: generation
            )
        })
    }

    nonisolated private static func buildVisibleItems(
        rootURL: URL,
        expandedURLs: Set<URL>,
        cachedItems: [URL: [FileItem]]
    ) -> (visibleItems: [FileItem], itemCache: [URL: [FileItem]], loadErrorMessage: String?) {
        var cache = cachedItems
        let rootItem = FileItem(url: rootURL, level: 0, isExpanded: expandedURLs.contains(rootURL))
        var result = [rootItem]
        var loadErrorMessage: String?

        if rootItem.isExpanded {
            loadErrorMessage = addVisibleChildren(
                from: rootItem,
                expandedURLs: expandedURLs,
                itemCache: &cache,
                into: &result
            )
        }

        return (result, cache, loadErrorMessage)
    }

    @discardableResult
    nonisolated private static func addVisibleChildren(
        from item: FileItem,
        expandedURLs: Set<URL>,
        itemCache: inout [URL: [FileItem]],
        into result: inout [FileItem]
    ) -> String? {
        let childLoad = itemCache[item.url].map { Result<[FileItem], Error>.success($0) } ?? childItems(for: item)

        guard case .success(let children) = childLoad else {
            if case .failure(let error) = childLoad {
                return "\(item.url.lastPathComponent): \(error.localizedDescription)"
            }

            return nil
        }

        itemCache[item.url] = children
        var loadErrorMessage: String?

        for child in children {
            let childItem = FileItem(
                url: child.url,
                level: child.level,
                isExpanded: expandedURLs.contains(child.url)
            )
            result.append(childItem)

            if childItem.isExpanded {
                loadErrorMessage = loadErrorMessage ?? addVisibleChildren(
                    from: childItem,
                    expandedURLs: expandedURLs,
                    itemCache: &itemCache,
                    into: &result
                )
            }
        }

        return loadErrorMessage
    }

    nonisolated private static func childItems(for item: FileItem) -> Result<[FileItem], Error> {
        do {
            guard let children = try item.children() else { return .success([]) }

            let filteredChildren = children
                .filter { child in
                    !ignoredFiles.contains(child.url.lastPathComponent)
                }
                .sorted { item1, item2 in
                    item1.url.lastPathComponent.localizedStandardCompare(item2.url.lastPathComponent) == .orderedAscending
                }

            return .success(filteredChildren)
        } catch {
            return .failure(error)
        }
    }

    @MainActor
    private func applyVisibleItemsUpdate(
        _ update: (visibleItems: [FileItem], itemCache: [URL: [FileItem]], loadErrorMessage: String?),
        generation: Int
    ) {
        guard FileListUpdatePolicy.shouldApplyResult(
            currentGeneration: updateGeneration,
            resultGeneration: generation
        ) else { return }

        visibleItems = update.visibleItems
        loadErrorMessage = update.loadErrorMessage
        itemCache.merge(update.itemCache) { _, new in new }
    }
}

#Preview(String(localized: "File List", bundle: .module)) {
    let url = URL(filePath: "/Users/user/Music")

    return FileListView(url: url, expandByDefault: true)
        .frame(height: 400)
        .padding()
}

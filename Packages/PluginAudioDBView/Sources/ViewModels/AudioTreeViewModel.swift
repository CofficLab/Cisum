import Combine
import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 音频仓库目录树的轻量加载容器（设置页「目录树」模式专用）。
///
/// 与主窗口内容区相互独立：设置页 onAppear 触发的重载不会传播到主窗口内容区。
/// 仅负责加载仓库目录树，不处理播放/选中态。
@MainActor
final class AudioTreeViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var children: [AudioTreeNode] = []
    @Published private(set) var isLoading = false

    private let diskProvider: @MainActor () -> URL?
    private var loadGeneration = 0

    init(disk: @escaping @MainActor () -> URL?) {
        self.diskProvider = disk
    }

    // MARK: - View lifecycle

    /// 视图出现（切换至「目录树」模式）：加载目录树。
    func handleOnAppear() {
        if Self.verbose { os_log("\(Self.t)📺 设置页加载仓库目录树") }
        load()
    }

    // MARK: - Loading

    private func load() {
        guard !isLoading else { return }

        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true

        Task { @MainActor in
            guard let disk = diskProvider() else {
                isLoading = false
                return
            }

            let children = await Task.detached(priority: .utility) {
                AudioTreeBuilder.buildRootChildren(from: disk)
            }.value
            guard generation == loadGeneration else { return }
            self.children = children
            self.isLoading = false
            if Self.verbose { os_log("\(Self.t)✅ 已加载 \(children.count) 个目录项") }
        }
    }
}

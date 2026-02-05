import Foundation
import MagicAlert
import MagicKit
import MagicPlayMan
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct BookLikeRootView<Content>: View, SuperLog where Content: View {
    nonisolated static var emoji: String { "📚❤️" }
    private let verbose = false

    @EnvironmentObject var man: PlayMan
    @EnvironmentObject var p: PluginProvider

    private var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .onAppear(perform: handleOnAppear)
    }

    /// 检查是否应该激活书籍喜欢管理功能
    private var shouldActivateLike: Bool {
        p.currentSceneName == "有声书"
    }
}

// MARK: - Action

extension BookLikeRootView {
    /// 处理视图出现事件
    ///
    /// 当视图首次出现时触发，执行初始化操作。
    func handleOnAppear() {
        guard shouldActivateLike else {
            if verbose {
                os_log("\(self.t)⏭️ 书籍喜欢管理跳过：当前插件不是书籍插件")
            }
            return
        }

        if verbose {
            os_log("\(self.t)👀 视图已出现，开始初始化书籍喜欢管理")
        }

        // 订阅播放器事件，监听喜欢状态变化
        man.subscribe(
            name: "BookLikePlugin",
            onLikeStatusChanged: { url, liked in
                handleLikeStatusChanged(url: url, liked: liked)
            }
        )
    }

    /// 处理喜欢状态变化事件
    ///
    /// 当用户点击喜欢/取消喜欢按钮时触发，更新独立的数据表。
    ///
    /// - Parameters:
    ///   - url: 书籍URL
    ///   - liked: 是否喜欢
    func handleLikeStatusChanged(url: URL, liked: Bool) {
        guard shouldActivateLike else { return }

        if verbose {
            os_log("\(self.t)❤️ 书籍喜欢状态变化: \(url.lastPathComponent) -> \(liked ? "喜欢" : "取消喜欢")")
        }

        Task {
            // 这里可以实现书籍喜欢状态的管理
            // 由于书籍喜欢功能相对简单，可以直接使用 UserDefaults 或简单的状态管理
            // 暂时记录日志，实际实现可以扩展为独立的书籍喜欢数据模型

            if liked {
                if verbose {
                    os_log("\(self.t)👍 书籍已标记为喜欢: \(url.lastPathComponent)")
                }
            } else {
                if verbose {
                    os_log("\(self.t)😔 书籍已取消喜欢: \(url.lastPathComponent)")
                }
            }

            // 发送通知，通知其他组件喜欢状态已更新
            NotificationCenter.default.post(
                name: .BookLikeStatusChanged,
                object: nil,
                userInfo: [
                    "url": url,
                    "liked": liked
                ]
            )
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// 书籍喜欢状态变化通知
    static let BookLikeStatusChanged = Notification.Name("BookLikeStatusChanged")
}

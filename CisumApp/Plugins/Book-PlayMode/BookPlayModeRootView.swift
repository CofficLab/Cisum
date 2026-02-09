import Foundation
import MagicAlert
import MagicKit
import MagicPlayMan
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct BookPlayModeRootView<Content>: View, SuperLog where Content: View {
    nonisolated static var emoji: String { "📖🔄" }
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

    /// 检查是否应该激活书籍播放模式管理功能
    private var shouldActivatePlayMode: Bool {
        p.currentSceneName == "有声书"
    }
}

// MARK: - Action

extension BookPlayModeRootView {
    /// 处理视图出现事件
    ///
    /// 当视图首次出现时触发，执行初始化操作。
    func handleOnAppear() {
        guard shouldActivatePlayMode else {
            if verbose {
                os_log("\(self.t)⏭️ 书籍播放模式管理跳过：当前插件不是书籍插件")
            }
            return
        }

        if verbose {
            os_log("\(self.t)👀 视图已出现，开始初始化书籍播放模式管理")
        }

        // 订阅播放器事件，监听播放模式变化
        man.subscribe(
            name: "BookPlayModePlugin",
            onPlayModeChanged: { mode in
                handlePlayModeChanged(mode)
            }
        )
    }

    /// 处理播放模式变化事件
    ///
    /// 当播放模式改变时触发，根据新模式处理书籍播放逻辑。
    ///
    /// - Parameter mode: 新的播放模式
    func handlePlayModeChanged(_ mode: PlayMode) {
        guard shouldActivatePlayMode else { return }

        if verbose {
            os_log("\(self.t)🔄 书籍播放模式变化 -> \(mode.shortName)")
        }

        // 对于书籍播放，播放模式主要影响章节间的切换逻辑
        switch mode {
        case .loop:
            if verbose {
                os_log("\(self.t)🔁 单曲循环模式 - 书籍将重复播放当前章节")
            }
            // 单曲循环：重复播放当前章节

        case .sequence, .repeatAll:
            if verbose {
                os_log("\(self.t)📋 顺序播放模式 - 书籍将按章节顺序播放")
            }
            // 顺序播放：按章节顺序播放

        case .shuffle:
            if verbose {
                os_log("\(self.t)🔀 随机播放模式 - 书籍章节将随机播放")
            }
            // 随机播放：章节随机播放
        }

        // 这里可以实现具体的书籍播放模式逻辑
        // 比如重新组织书籍的播放队列等
        if verbose {
            os_log("\(self.t)⚠️ 书籍播放模式逻辑待实现")
        }
    }
}

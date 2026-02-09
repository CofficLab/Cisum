import Foundation
import MagicAlert
import MagicKit
import MagicPlayMan
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct AudioPlayModeRootView<Content>: View, SuperLog where Content: View {
    nonisolated static var emoji: String { "🔄" }
    private static var verbose: Bool { false }

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

    /// 检查是否应该激活播放模式管理功能
    private var shouldActivatePlayMode: Bool {
        p.currentSceneName == "音乐库"
    }
}

// MARK: - Action

extension AudioPlayModeRootView {
    /// 处理视图出现事件
    ///
    /// 当视图首次出现时触发，执行初始化操作。
    func handleOnAppear() {
        guard shouldActivatePlayMode else {
            if Self.verbose {
                os_log("\(self.t)⏭️ 播放模式管理跳过：当前插件不是音频插件")
            }
            return
        }

        if Self.verbose {
            os_log("\(self.t)👀 视图已出现，开始初始化播放模式管理")
        }

        // 订阅播放器事件
        man.subscribe(
            name: "AudioPlayModePlugin",
            onPlayModeChanged: { mode in
                handlePlayModeChanged(mode)
            }
        )
    }

    /// 处理播放模式变化事件
    ///
    /// 当播放模式改变时触发，根据新模式重新排序音频列表。
    ///
    /// - Parameter mode: 新的播放模式
    func handlePlayModeChanged(_ mode: PlayMode) {
        guard shouldActivatePlayMode else { return }

        if Self.verbose {
            os_log("\(self.t)🔄 播放模式变化 -> \(mode.shortName)")
        }

        // 存储播放模式设置
        Task {
            await AudioPlayModeRepo.shared.storePlayMode(mode)
        }

        guard let repo = AudioPlugin.getAudioRepo() else {
            return
        }

        // 根据播放模式重新排序音频列表
        Task {
            let currentURL = self.man.currentURL

            switch mode {
            case .loop:
                if Self.verbose {
                    os_log("\(self.t)🔁 单曲循环模式")
                }

                alert_info("单曲循环")
            case .sequence, .repeatAll:
                if Self.verbose {
                    os_log("\(self.t)📋 顺序播放，重新排序")
                }

                alert_info("顺序播放")
                await repo.sort(currentURL, reason: "PlayModeChanged")
            case .shuffle:
                if Self.verbose {
                    os_log("\(self.t)🔀 随机播放，打乱顺序")
                }

                alert_info("随机播放")
                try await repo.sortRandom(currentURL, reason: "PlayModeChanged", verbose: false)
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// 音频播放模式变化通知
    static let AudioPlayModeChanged = Notification.Name("AudioPlayModeChanged")
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

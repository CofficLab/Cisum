import Foundation
import MagicAlert
import MagicKit
import MagicPlayMan
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AudioLikeRootView<Content>: View, SuperLog where Content: View {
    nonisolated static var emoji: String { "❤️" }
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
            .onAudioLikeStatusChanged(perform: handleLikeStatusChanged)
    }

    /// 检查是否应该激活喜欢管理功能
    private var shouldActivateLike: Bool {
        p.currentSceneName == "音乐库"
    }
}

// MARK: - Action

extension AudioLikeRootView {
    /// 处理视图出现事件
    ///
    /// 当视图首次出现时触发，执行初始化操作。
    func handleOnAppear() {
        guard shouldActivateLike else {
            if Self.verbose {
                os_log("\(self.t)⏭️ 喜欢管理跳过：当前插件不是音频插件")
            }
            return
        }

        if Self.verbose {
            os_log("\(self.t)👀 视图已出现，开始初始化喜欢管理")
        }
    }

    /// 处理喜欢状态变化事件
    ///
    /// 当用户点击喜欢/取消喜欢按钮时触发，更新独立的数据表。
    ///
    /// - Parameter liked: 是否喜欢
    func handleLikeStatusChanged(audioId: String, url: URL?, liked: Bool) {
        guard shouldActivateLike else { return }

        guard let currentURL = man.currentURL else {
            if Self.verbose {
                os_log("\(self.t)⚠️ 没有当前播放的音频")
            }
            return
        }

        Task {
            let audioId = currentURL.absoluteString // 使用 URL 作为唯一标识符

            do {
                // 获取或创建喜欢状态模型
                if let existingModel = try await AudioLikeRepo.shared.findLikeModel(audioId: audioId) {
                    // 更新现有记录
                    existingModel.liked = liked
                    existingModel.updatedAt = Date()
                    try await AudioLikeRepo.shared.save(existingModel)
                } else {
                    // 创建新记录
                    let newModel = AudioLikeModel(
                        audioId: audioId,
                        url: currentURL,
                        title: currentURL.lastPathComponent,
                        liked: liked
                    )
                    try await AudioLikeRepo.shared.save(newModel)
                }

                if Self.verbose {
                    os_log("\(self.t)💾 保存喜欢状态: \(currentURL.lastPathComponent) -> \(liked ? "喜欢" : "取消喜欢")")
                }

                // 发送通知，通知其他组件喜欢状态已更新
                NotificationCenter.default.post(
                    name: .AudioLikeStatusChanged,
                    object: nil,
                    userInfo: [
                        "url": currentURL,
                        "liked": liked,
                    ]
                )

            } catch {
                os_log(.error, "\(self.t)❌ 保存喜欢状态失败: \(error.localizedDescription)")
                alert_error("保存喜欢状态失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// 音频喜欢状态变化通知
    static let AudioLikeStatusChanged = Notification.Name("AudioLikeStatusChanged")
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

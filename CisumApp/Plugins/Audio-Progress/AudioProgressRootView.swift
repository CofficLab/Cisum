import AVFoundation
import Foundation
import MagicAlert
import MagicKit
import MagicPlayMan
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

struct AudioProgressRootView<Content>: View, SuperLog where Content: View {
    nonisolated static var emoji: String { "💾" }
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
            .onPlayManStateChanged(handlePlayManStateChanged)
            .onPlayManAssetChanged(handlePlayManAssetChanged)
            // 注意：存储位置变更时，本RootView会被卸载掉，光靠 onPlayManAssetChanged 无法监听到
            .onStorageLocationDidReset(perform: handleStorageLocationDidReset)
    }

    /// 检查是否应该激活进度管理功能
    private var shouldActivateProgress: Bool {
        p.currentSceneName == AudioScenePlugin.sceneName
    }
}

// MARK: - Action

extension AudioProgressRootView {
    /// 恢复播放模式
    ///
    /// 从持久化存储中读取上次的播放模式并应用到播放器。
    /// 播放模式包括：顺序播放、单曲循环、随机播放等。

    /// 恢复上次播放状态
    ///
    /// 从持久化存储中恢复上次播放的音频、播放进度和喜欢状态。
    /// 如果没有上次播放记录，或该文件已不存在，则播放第一首音频。
    ///
    /// ## 恢复流程
    /// 1. 读取上次播放的 URL 和时间
    /// 2. 检查该 URL 是否存在于 AudioRepo
    /// 3. 如果存在，恢复该音频和进度
    /// 4. 如果不存在或没找到记录，播放第一首音频
    /// 5. 恢复喜欢状态
    private func restorePlaying() {
        var assetTarget: URL?
        var timeTarget: TimeInterval = 0
        var liked = false

        Task {
            // 从 AudioPlugin 获取 AudioRepo 实例
            guard let repo = AudioPlugin.getAudioRepo() else {
                if Self.verbose {
                    os_log(.error, "\(self.t)❌ 获取 AudioRepo 失败")
                }
                return
            }

            // 尝试恢复上次播放
            if let url = AudioStateRepo.getCurrent() {
                // 检查该 URL 是否存在于 AudioRepo
                if await repo.find(url) != nil {
                    // 文件存在，恢复播放
                    assetTarget = url
                    liked = await AudioLikeRepo.shared.isLiked(url: url)

                    if let time = AudioStateRepo.getCurrentTime() {
                        timeTarget = time
                    }

                    if Self.verbose {
                        os_log("\(self.t)✅ 恢复播放: \(url.lastPathComponent) @ \(timeTarget)s")
                    }
                } else {
                    // 文件不存在，播放第一首
                    if Self.verbose {
                        os_log("\(self.t)⚠️ 上次播放的文件不存在: \(url.lastPathComponent)")
                    }

                    if let firstUrl = try? await repo.getFirst() {
                        assetTarget = firstUrl
                        liked = await AudioLikeRepo.shared.isLiked(url: firstUrl)

                        if Self.verbose {
                            os_log("\(self.t)✅ 播放第一首: \(firstUrl.lastPathComponent)")
                        }
                    }
                }
            } else {
                if Self.verbose {
                    os_log("\(self.t)⚠️ 没有上次播放记录")
                }
            }

            if let asset = assetTarget {
                let reason = self.className + ".初始化播放数据"
                await man.play(asset, autoPlay: false, reason: reason)
                man.seek(time: timeTarget, reason: reason)
                man.setLike(liked, reason: reason)
            } else {
                if Self.verbose {
                    os_log("\(self.t)⚠️ 没有初始化播放数据")
                }
            }
        }
    }
}

// MARK: - Event Handler

extension AudioProgressRootView {
    /// 处理视图出现事件
    ///
    /// 当视图首次出现时触发，执行初始化操作。
    ///
    /// ## 初始化流程
    /// 1. 恢复上次播放状态
    /// 2. 恢复播放模式
    func handleOnAppear() {
        guard shouldActivateProgress else {
            return
        }

        self.restorePlaying()
    }

    /// 处理播放器状态变化事件
    ///
    /// 当播放器状态改变时触发（播放/暂停/停止等）。
    /// 在暂停时会保存当前播放进度。
    ///
    /// - Parameter isPlaying: 是否正在播放
    func handlePlayManStateChanged(_ isPlaying: Bool) {
        guard shouldActivateProgress else { return }

        // Sync to Widget
        syncToWidget(url: man.currentAsset, isPlaying: isPlaying)

        if self.man.state == .paused {
            AudioStateRepo.storeCurrentTime(man.currentTime)

            if Self.verbose {
                os_log("\(self.t)💾 保存播放进度: \(man.currentTime)s")
            }
        }
    }

    /// 处理播放资源变化事件
    ///
    /// 当播放器的音频资源改变时触发，保存当前播放的 URL。
    ///
    /// - Parameter url: 新的音频资源 URL，如果为 nil 则表示停止播放
    func handlePlayManAssetChanged(_ url: URL?) {
        guard shouldActivateProgress else { return }

        // Sync to Widget
        syncToWidget(url: url, isPlaying: man.state == .playing)

        guard let url = url else {
            return
        }

        Task {
            AudioStateRepo.storeCurrent(url)
        }
    }
    
    private func syncToWidget(url: URL?, isPlaying: Bool) {
        guard let url = url else {
            WidgetData.save(title: "Not Playing", artist: "Cisum", isPlaying: false, coverArt: nil)
            return
        }
        
        let title = url.deletingPathExtension().lastPathComponent
        let artist = "Cisum" // Placeholder
        
        Task {
            var coverArt: Data? = nil
            let asset = AVAsset(url: url)
            do {
                let metadata = try await asset.load(.commonMetadata)
                if let artworkItem = metadata.first(where: { $0.commonKey == .commonKeyArtwork }),
                   let data = try await artworkItem.load(.value) as? Data {
                    coverArt = data
                }
            } catch {
                if Self.verbose {
                    os_log(.error, "\(self.t) Failed to load artwork: \(error.localizedDescription)")
                }
            }
            
            WidgetData.save(title: title, artist: artist, isPlaying: isPlaying, coverArt: coverArt)
        }
    }

    /// 处理存储位置重置事件
    ///
    /// 当存储位置被重置时，停止当前播放。
    func handleStorageLocationDidReset() {
        guard shouldActivateProgress else { return }

        if Self.verbose {
            os_log("\(self.t)🛑 存储位置重置，记录播放进度")
        }

        // 直接在主线程上调用，避免后台线程发布 @Published 属性
        AudioStateRepo.storeCurrentTime(man.currentTime)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

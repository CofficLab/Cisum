import SwiftUI
import MagicKit
import MagicPlayMan
import OSLog
import CoreFoundation

/// 负责响应 Widget 控制命令的视图
/// 本视图不可见，仅用于监听通知并执行播放控制
struct AudioWidgetControlRootView: View, SuperLog {
    nonisolated static let emoji = "🎛️"
    private static var verbose: Bool { true }

    @EnvironmentObject var man: MagicPlayMan

    // 从 AudioPlugin 获取 AudioRepo 实例
    private var audioRepo: AudioRepo? {
        AudioPlugin.getAudioRepo()
    }

    var body: some View {
        EmptyView()
            .onAppear {
                setupWidgetCommandListener()
            }
            // 监听 App Groups UserDefaults 变化（通常由 Darwin 通知触发同步后引起）
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                handleWidgetCommands()
            }
            // 监听 Darwin 通知转换来的本地通知
            .onReceive(NotificationCenter.default.publisher(for: .widgetCommandReceived)) { _ in
                handleWidgetCommands()
            }
    }

    private func setupWidgetCommandListener() {
        // 监听 Darwin 通知
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        
        // 定义回调
        let callback: CFNotificationCallback = { _, _, _, _, _ in
            // 在主线程发送本地通知，触发 View 更新
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .widgetCommandReceived, object: nil)
            }
        }
        
        CFNotificationCenterAddObserver(center, nil, callback, "com.yueyi.cisum.widgetCommand" as CFString, nil, .deliverImmediately)
        
        if Self.verbose {
            os_log("\(Self.t)🍋 已注册 Widget 命令监听器")
        }
    }

    private func handleWidgetCommands() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.yueyi.cisum")
        // 强制同步，确保读到最新数据
        sharedDefaults?.synchronize()
        
        guard let sharedDefaults = sharedDefaults else { return }

        // 检查播放/暂停命令
        if let _ = sharedDefaults.object(forKey: "widgetPlayPauseTrigger") as? TimeInterval {
            if Self.verbose {
                os_log("\(Self.t)📱 收到 Widget 播放/暂停命令")
            }
            handlePlayPause()
            // 清除触发器
            sharedDefaults.removeObject(forKey: "widgetPlayPauseTrigger")
        }

        // 检查下一首命令
        if let _ = sharedDefaults.object(forKey: "widgetNextTrigger") as? TimeInterval {
            if Self.verbose {
                os_log("\(Self.t)📱 收到 Widget 下一首命令")
            }
            handleNext()
            sharedDefaults.removeObject(forKey: "widgetNextTrigger")
        }

        // 检查上一首命令
        if let _ = sharedDefaults.object(forKey: "widgetPreviousTrigger") as? TimeInterval {
            if Self.verbose {
                os_log("\(Self.t)📱 收到 Widget 上一首命令")
            }
            handlePrevious()
            sharedDefaults.removeObject(forKey: "widgetPreviousTrigger")
        }
    }
    
    // MARK: - Playback Control
    
    private func handlePlayPause() {
        if man.state == .playing {
            man.pause(reason: "Widget")
        } else {
            man.playCurrent(reason: "Widget")
        }
    }
    
    private func handleNext() {
        guard let asset = man.currentAsset, let repo = audioRepo else { return }
        
        Task {
            do {
                if let next = try await repo.getNextOf(asset, verbose: Self.verbose) {
                    await man.play(next, autoPlay: true, reason: "Widget.Next")
                } else if let first = try await repo.getFirst() {
                    // 如果没有下一首，循环播放第一首
                    await man.play(first, autoPlay: true, reason: "Widget.Loop")
                }
            } catch {
                if Self.verbose {
                    os_log("\(Self.t)❌ 获取下一首失败: \(error.localizedDescription)")
                }
            }
        }
    }

    private func handlePrevious() {
        guard let asset = man.currentAsset, let repo = audioRepo else { return }

        Task {
            do {
                if let prev = try await repo.getPrevOf(asset, verbose: Self.verbose) {
                    await man.play(prev, autoPlay: true, reason: "Widget.Previous")
                }
            } catch {
                if Self.verbose {
                    os_log("\(Self.t)❌ 获取上一首失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

extension Notification.Name {
    /// 收到 Widget 的 Darwin 通知后转发的本地通知
    static let widgetCommandReceived = Notification.Name("widgetCommandReceived")
}

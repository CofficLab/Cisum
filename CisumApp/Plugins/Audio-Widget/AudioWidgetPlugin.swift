import Foundation
import MagicKit
import OSLog
import SwiftUI
import WidgetKit

/// 音频小组件插件
/// 负责在音频播放状态变化时更新小组件数据
actor AudioWidgetPlugin: SuperPlugin {
    static let emoji = "📱"
    nonisolated static let order = 999 // 最后执行，确保其他插件已初始化

    private let logger = Logger(subsystem: "com.cofficlab.cisum", category: "AudioWidget")

    // App Group
    private let appGroup = "group.com.cofficlab.cisum"

    func onBoot() async throws {
        logger.log("\(Self.emoji) 音频小组件插件已启动")

        // 小组件插件初始化成功
        // 小组件数据更新由主应用通过 UserDefaults + WidgetCenter.shared.reloadAllTimelines() 驱动
    }

    /// 刷新小组件
    nonisolated static func refreshWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - SuperPlugin Requirements

    nonisolated var id: String {
        "AudioWidgetPlugin"
    }

    nonisolated var label: String {
        "widget"
    }

    nonisolated var title: String {
        "音频小组件"
    }

    nonisolated var description: String {
        "音频播放小组件数据同步"
    }

    nonisolated var iconName: String {
        "music.note"
    }

    nonisolated static var shouldRegister: Bool {
        true
    }

    // MARK: - View Methods (default implementations)

    @MainActor func addSceneItem() -> String? {
        nil
    }

    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        nil
    }

    @MainActor func addGuideView() -> AnyView? {
        nil
    }

    @MainActor func addSheetView(storage: StorageLocation?) -> AnyView? {
        nil
    }

    @MainActor func addPosterView() -> AnyView? {
        nil
    }

    @MainActor func addToolbarView() -> AnyView? {
        nil
    }

    @MainActor func addStatusView() -> AnyView? {
        nil
    }

    @MainActor func addSettingsView() -> AnyView? {
        nil
    }

    @MainActor func addTabView() -> AnyView? {
        nil
    }

    @MainActor func addTabViewSetting() -> AnyView? {
        nil
    }

    func onLaunch() async throws {}

    func onForeground() async throws {}

    func onBackground() async throws {}
}

// MARK: - 通知名称扩展

extension Notification.Name {
    /// 音频播放状态变化通知
    /// userInfo: ["isPlaying": Bool]
    static let audioPlayStateChanged = Notification.Name("audioPlayStateChanged")

    /// 当前播放音频变化通知
    /// userInfo: ["audioURL": URL, "title": String]
    static let audioCurrentChanged = Notification.Name("audioCurrentChanged")

    /// 播放进度变化通知
    /// userInfo: ["progress": Double]
    static let audioProgressChanged = Notification.Name("audioProgressChanged")

    /// 小组件控制通知
    static let widgetTogglePlayPause = Notification.Name("widgetTogglePlayPause")
    static let widgetPlayNext = Notification.Name("widgetPlayNext")
    static let widgetPlayPrevious = Notification.Name("widgetPlayPrevious")
    static let widgetOpenApp = Notification.Name("widgetOpenApp")
}

// MARK: - 小组件数据更新辅助方法

extension AudioWidgetPlugin {
    /// 通知当前播放音频信息
    /// - Parameters:
    ///   - url: 音频URL
    ///   - title: 音频标题
    nonisolated static func notifyCurrentAudio(url: URL, title: String) {
        NotificationCenter.default.post(
            name: .audioCurrentChanged,
            object: nil,
            userInfo: ["audioURL": url, "title": title]
        )
    }

    /// 通知播放状态变化
    /// - Parameter isPlaying: 是否正在播放
    nonisolated static func notifyPlayState(isPlaying: Bool) {
        NotificationCenter.default.post(
            name: .audioPlayStateChanged,
            object: nil,
            userInfo: ["isPlaying": isPlaying]
        )
    }

    /// 通知播放进度变化
    /// - Parameter progress: 播放进度（0-1）
    nonisolated static func notifyProgress(progress: Double) {
        NotificationCenter.default.post(
            name: .audioProgressChanged,
            object: nil,
            userInfo: ["progress": progress]
        )
    }
}

import Foundation

/// 内核级事件枚举。
///
/// 所有需要跨模块广播的内核事件统一在此定义。
/// 插件与 UI 层通过 `NotificationCenter` 订阅这些事件。
///
/// ## 新增事件
///
/// 在此枚举中添加新的 case，然后在 `Notification.Name` 扩展中添加对应的
/// 静态属性，最后在 `EventManager` 中添加便捷发送方法。
public enum CisumKernelEvent: String, CaseIterable, Sendable {
    /// 主题已变更。
    case themeDidChange = "com.coffic.cisum.themeDidChange"

    /// 播放状态已变更。
    case playbackStateDidChange = "com.coffic.cisum.playbackStateDidChange"

    /// 播放进度已更新。
    case playbackProgressDidUpdate = "com.coffic.cisum.playbackProgressDidUpdate"

    /// 当前播放资源已变更。
    case playbackAssetDidChange = "com.coffic.cisum.playbackAssetDidChange"

    /// iCloud 状态已变更。
    case cloudStatusDidChange = "com.coffic.cisum.cloudStatusDidChange"

    /// 引导流程已完成。
    case guideDidComplete = "com.coffic.cisum.guideDidComplete"

    /// 应用程序生命周期事件。
    case appLifecycleDidChange = "com.coffic.cisum.appLifecycleDidChange"

    /// 音频数据库已同步。
    case audioDBSynced = "com.coffic.cisum.audioDBSynced"

    /// 音频数据库已更新。
    case audioDBUpdated = "com.coffic.cisum.audioDBUpdated"

    // MARK: - Notification Name

    public var notificationName: Notification.Name {
        Notification.Name(rawValue)
    }
}

// MARK: - Notification.Name Convenience

extension Notification.Name {
    public static let cisumThemeDidChange = CisumKernelEvent.themeDidChange.notificationName
    public static let cisumPlaybackStateDidChange = CisumKernelEvent.playbackStateDidChange.notificationName
    public static let cisumPlaybackProgressDidUpdate = CisumKernelEvent.playbackProgressDidUpdate.notificationName
    public static let cisumPlaybackAssetDidChange = CisumKernelEvent.playbackAssetDidChange.notificationName
    public static let cisumCloudStatusDidChange = CisumKernelEvent.cloudStatusDidChange.notificationName
    public static let cisumGuideDidComplete = CisumKernelEvent.guideDidComplete.notificationName
    public static let cisumAppLifecycleDidChange = CisumKernelEvent.appLifecycleDidChange.notificationName
    public static let cisumAudioDBSynced = CisumKernelEvent.audioDBSynced.notificationName
    public static let cisumAudioDBUpdated = CisumKernelEvent.audioDBUpdated.notificationName
}

// MARK: - NotificationCenter Convenience Subscriptions

extension NotificationCenter {
    /// 订阅 `.cisumThemeDidChange`。
    @MainActor
    public func onCisumThemeDidChange(_ handler: @escaping () -> Void) -> NSObjectProtocol {
        addObserver(forName: .cisumThemeDidChange, object: nil, queue: .main) { _ in
            handler()
        }
    }

    /// 订阅 `.cisumPlaybackStateDidChange`。
    @MainActor
    public func onCisumPlaybackStateDidChange(_ handler: @escaping () -> Void) -> NSObjectProtocol {
        addObserver(forName: .cisumPlaybackStateDidChange, object: nil, queue: .main) { _ in
            handler()
        }
    }

    /// 订阅 `.cisumCloudStatusDidChange`。
    @MainActor
    public func onCisumCloudStatusDidChange(_ handler: @escaping () -> Void) -> NSObjectProtocol {
        addObserver(forName: .cisumCloudStatusDidChange, object: nil, queue: .main) { _ in
            handler()
        }
    }
}

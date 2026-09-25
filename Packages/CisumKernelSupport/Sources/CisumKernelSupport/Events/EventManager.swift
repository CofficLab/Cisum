import Foundation
import MagicKit
import OSLog

/// 内核事件分发器。
///
/// 所有需要对外广播的内核事件都通过此对象统一发送。
///
/// ## 使用示例
///
/// ```swift
/// // 发送主题变更事件
/// kernel.eventManager.postThemeDidChange()
///
/// // 发送播放状态变更
/// kernel.eventManager.postPlaybackStateDidChange()
/// ```
@MainActor
public final class EventManager: ObservableObject, SuperLog {
    nonisolated public static let emoji = "📣"
    nonisolated(unsafe) public static var verbose = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.cisum",
        category: "kernel.event-manager"
    )

    public init() {}

    /// 发送通用内核事件。
    ///
    /// - Parameters:
    ///   - event: 内核事件。
    ///   - object: 发送者对象。
    ///   - userInfo: 附加信息字典。
    public func post(
        _ event: CisumKernelEvent,
        object: Any? = nil,
        userInfo: [AnyHashable: Any]? = nil
    ) {
        if Self.verbose {
            Self.logger.info(
                "\(Self.t)post event=\(event.rawValue) object=\(String(describing: object.map { type(of: $0) }))"
            )
        }
        NotificationCenter.default.post(
            name: event.notificationName,
            object: object,
            userInfo: userInfo
        )
    }

    // MARK: - Convenience Methods

    /// 发送主题变更事件。
    public func postThemeDidChange(object: Any? = nil) {
        post(.themeDidChange, object: object)
    }

    /// 发送存储位置变更事件。
    public func postStorageLocationDidChange(object: Any? = nil) {
        post(.storageLocationDidChange, object: object)
    }

    /// 发送存储位置重置事件。
    public func postStorageLocationDidReset(object: Any? = nil) {
        post(.storageLocationDidReset, object: object)
    }

    /// 发送已启用插件变更事件。
    public func postEnabledPluginsDidChange(object: Any? = nil) {
        post(.enabledPluginsDidChange, object: object)
    }

    /// 发送播放状态变更事件。
    ///
    /// - Parameters:
    ///   - isPlaying: 是否正在播放。
    ///   - object: 发送者对象。
    public func postPlaybackStateDidChange(isPlaying: Bool? = nil, object: Any? = nil) {
        var userInfo: [AnyHashable: Any]?
        if let isPlaying {
            userInfo = ["isPlaying": isPlaying]
        }
        post(.playbackStateDidChange, object: object, userInfo: userInfo)
    }

    /// 发送播放进度更新事件。
    ///
    /// - Parameters:
    ///   - progress: 当前进度 (0.0 ~ 1.0)。
    ///   - currentTime: 当前时间。
    ///   - object: 发送者对象。
    public func postPlaybackProgressDidUpdate(
        progress: Double,
        currentTime: TimeInterval,
        object: Any? = nil
    ) {
        post(.playbackProgressDidUpdate, object: object, userInfo: [
            "progress": progress,
            "currentTime": currentTime,
        ])
    }

    /// 发送当前播放资源变更事件。
    ///
    /// - Parameters:
    ///   - title: 新资源标题。
    ///   - object: 发送者对象。
    public func postPlaybackAssetDidChange(
        title: String? = nil,
        object: Any? = nil
    ) {
        var userInfo: [AnyHashable: Any]?
        if let title {
            userInfo = ["title": title]
        }
        post(.playbackAssetDidChange, object: object, userInfo: userInfo)
    }

    /// 发送 iCloud 状态变更事件。
    public func postCloudStatusDidChange(object: Any? = nil) {
        post(.cloudStatusDidChange, object: object)
    }

    /// 发送引导完成事件。
    public func postGuideDidComplete(object: Any? = nil) {
        post(.guideDidComplete, object: object)
    }

    /// 发送应用生命周期变更事件。
    ///
    /// - Parameter phase: 生命周期阶段描述。
    public func postAppLifecycleDidChange(phase: String, object: Any? = nil) {
        post(.appLifecycleDidChange, object: object, userInfo: ["phase": phase])
    }

    /// 发送音频数据库同步完成事件。
    public func postAudioDBSynced(object: Any? = nil) {
        post(.audioDBSynced, object: object)
    }

    /// 发送音频数据库更新事件。
    public func postAudioDBUpdated(object: Any? = nil) {
        post(.audioDBUpdated, object: object)
    }
}

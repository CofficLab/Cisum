import OSLog
import SwiftUI

// MARK: - URL Avatar View Extension
public extension URL {
    /// 为 URL 创建一个头像视图
    /// 
    /// 头像视图是一个突出显示文件缩略图的视图组件，它可以：
    /// - 自动生成并显示文件缩略图
    /// - 展示文件下载进度
    /// - 处理错误状态
    /// - 支持自定义形状和背景色
    /// - 支持多种尺寸设置方式
    /// 
    /// # 基础用法
    /// ```swift
    /// // 创建基础视图
    /// let avatarView = url.makeAvatarView()
    /// 
    /// // 自定义形状
    /// let customView = url.makeAvatarView()
    ///     .magicShape(.roundedRectangle(cornerRadius: 8))
    /// ```
    /// 
    /// # 自定义外观
    /// ```swift
    /// // 设置背景色
    /// let coloredView = url.makeAvatarView()
    ///     .magicBackground(.blue.opacity(0.1))
    /// 
    /// // 设置尺寸
    /// let sizedView = url.makeAvatarView()
    ///     .magicSize(64)  // 正方形边长
    /// 
    /// // 自定义宽高
    /// let rectangleView = url.makeAvatarView()
    ///     .magicSize(width: 80, height: 60)
    /// ```
    /// 
    /// # 下载进度
    /// ```swift
    /// // 自动监听 iCloud 文件
    /// let cloudView = url.makeAvatarView()
    ///
    /// // 手动控制进度
    /// @State var progress: Double = 0
    /// let progressView = url.makeAvatarView()
    ///     .magicDownloadProgress($progress)
    /// ```
    ///
    /// # 性能警告 - 下载监控
    /// **✅ 好消息：MagicKit 现在内部使用全局下载进度管理器！**
    ///
    /// 从当前版本开始，`magicDownloadMonitor` 已优化为使用全局监控器。
    /// 每个文件 URL 只会创建一个监听器，多个视图共享同一个进度源。
    ///
    /// ## 现在可以安全使用的场景：
    /// - ✅ 列表/集合视图（即使有上百个项目）
    /// - ✅ 快速滚动的视图
    /// - ✅ 详情页、播放器界面
    ///
    /// ## 工作原理：
    /// 1. **全局单例**：`GlobalDownloadMonitor.shared` 集中管理所有下载进度
    /// 2. **引用计数**：自动跟踪每个 URL 的订阅者数量
    /// 3. **自动清理**：当没有订阅者时自动清理监听器
    /// 4. **零配置**：无需额外代码，直接使用即可
    ///
    /// ## 使用示例：
    /// ```swift
    /// // ✅ 列表中直接使用，无需担心性能
    /// url.makeAvatarView()
    ///     .magicDownloadMonitor(true)
    ///
    /// // ✅ 多个视图显示同一个文件，自动共享进度
    /// // (例如列表中的头像 + 播放器中的头像)
    /// ```
    ///
    /// ## 内部实现：
    /// ```swift
    /// @MainActor
    /// public final class GlobalDownloadMonitor {
    ///     public static let shared = GlobalDownloadMonitor()
    ///
    ///     // 每个 URL 只创建一个监听器
    ///     public func subscribe(url: URL) -> AnyPublisher<Double>
    ///     public func unsubscribe(url: URL)
    /// }
    /// ```
    /// 
    /// # 错误处理
    /// 视图会自动处理并显示以下错误：
    /// - 缩略图生成失败
    /// - 文件访问错误
    /// - 下载失败
    /// 
    /// - Returns: 配置好的头像视图
    func makeAvatarView(verbose: Bool = false) -> AvatarView {
        return AvatarView(url: self, verbose: verbose)
    }
}


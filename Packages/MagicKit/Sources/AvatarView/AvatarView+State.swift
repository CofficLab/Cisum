import SwiftUI

extension AvatarView {
    /// 头像视图的状态管理
    @MainActor public final class ViewState: ObservableObject {
        /// 缩略图
        @Published public var thumbnail: Image?

        /// 是否为系统图标
        @Published public var isSystemIcon: Bool = false

        /// 错误状态
        @Published public var error: Error?

        /// 是否已有结论（封面 / 云端未下载图标 / 确实出错）。
        ///
        /// 「文件不存在」只是初判：iCloud 占位文件在下载完成前本地并不存在，
        /// 但它并不是错误——缩略图生成器能把它解析成「云端未下载」图标。
        /// 没有这个标记，视图会在结论出来之前先把红色感叹号画出来。
        @Published public var isResolved = false

        /// 加载状态
        @Published public var isLoading = false

        /// 自动下载进度
        @Published public var autoDownloadProgress: Double = 0

        /// 标记是否需要重新加载缩略图（下载完成后触发）
        @Published public var needsReload = false

        /// 创建一个新的视图状态实例
        /// - Parameter error: 初始错误状态，默认为 nil
        public init(error: Error? = nil) {
            self.error = error
        }

        /// 重置所有状态
        public func reset() {
            thumbnail = nil
            isSystemIcon = false
            error = nil
            isLoading = false
            isResolved = false
            autoDownloadProgress = 0
        }

        /// 设置加载状态
        public func setLoading(_ loading: Bool) {
            isLoading = loading
        }

        /// 设置错误状态
        public func setError(_ error: Error?) {
            self.error = error
        }

        /// 标记已有结论：此后才允许渲染错误态。
        public func setResolved(_ resolved: Bool) {
            self.isResolved = resolved
        }

        /// 设置缩略图
        public func setThumbnail(_ image: Image?) {
            self.thumbnail = image
        }

        /// 设置缩略图和图标类型
        public func setThumbnail(_ image: Image?, isSystemIcon: Bool) {
            self.thumbnail = image
            self.isSystemIcon = isSystemIcon
        }

        /// 设置下载进度
        public func setProgress(_ progress: Double) {
            self.autoDownloadProgress = progress
        }

        /// 标记下载完成，需要重新加载缩略图
        public func markNeedsReload() {
            reset()
            needsReload = true
        }

        /// 清除重新加载标记
        public func clearNeedsReload() {
            needsReload = false
        }
    }
}
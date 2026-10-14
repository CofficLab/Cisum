import Foundation
import MagicKit
import LumiUI
import SwiftUI

/// 列表项的文件大小标签。
///
/// 与 `AudioDownloadProgressRing` 同构：直接观察 `CloudDownloadProgressStore`，
/// 不经由 `AudioItemView` 传值，因此不受 `AudioList` 对整行 `.equatable()` 的短路影响。
///
/// ## 为什么需要「下载完成后重读」
///
/// iCloud「优化存储」下的文件在下载完成前只是一个占位符，读到的大小是 `0` 或读不到；
/// 下载完成后真实内容才落到磁盘，大小随之变化。原先大小只在 `.task(id: url)`
/// 里读一次，url 不变就不会重读——用户会看到进度环转完、文件出现，大小却一直显示
/// 「不可用」或旧值。
///
/// 现在以 `downloadStore` 的完成计数作为 `.task` 的触发条件：每完成一次下载就
/// 重读一次，封面与大小同步刷新。
struct AudioItemFileSizeLabel: View {
    let url: URL
    @ObservedObject private var downloadStore: CloudDownloadProgressStore

    @State private var fileSize: Int64?
    @State private var isUnavailable = false

    init(url: URL, downloadStore: CloudDownloadProgressStore) {
        self.url = url
        self._downloadStore = ObservedObject(wrappedValue: downloadStore)
    }

    var body: some View {
        content
            // 以完成计数为标识：下载完成一次即重新读取大小。
            .task(id: reloadToken) {
                await loadFileSize()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch AudioItemFileSizeDisplayPolicy.state(
            fileSize: fileSize,
            isUnavailable: isUnavailable
        ) {
        case .size(let fileSize):
            AppSizeLabel(bytes: fileSize)
        case .unavailable:
            Text("Unavailable", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
        case .loading:
            Text("...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// 该文件已完成的下载次数；用于在下载完成后触发重读。
    private var reloadToken: Int {
        downloadStore.reloadToken(for: url)
    }

    private func loadFileSize() async {
        let requestedURL = url

        // 缓存命中直接用，避免列表滚动时重复读磁盘、也避免闪烁。
        if let cachedSize = AudioItemFileSizeCache.cachedSize(for: requestedURL) {
            fileSize = cachedSize
            isUnavailable = cachedSize == nil
            return
        }

        // 只有确实需要重新读取时才清空，避免先闪一下再显示。
        fileSize = nil
        isUnavailable = false

        let size = await Task.detached(priority: .background) {
            AudioItemFileSizeReadPolicy.currentFileSize(for: requestedURL)
        }.value

        guard !Task.isCancelled,
              AudioItemFileSizeLoadPolicy.shouldApplySize(currentURL: url, requestedURL: requestedURL) else {
            return
        }

        // 失败不入缓存：必须允许下次重试，否则下载完成后永远显示「不可用」。
        AudioItemFileSizeCache.store(size, for: requestedURL)
        fileSize = size
        isUnavailable = size == nil
    }
}
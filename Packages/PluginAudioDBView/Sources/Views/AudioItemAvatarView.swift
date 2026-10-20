import Combine
import MagicKit
import SwiftUI

/// 头像重建标识：URL + 缩略图重载次数。
///
/// iCloud 文件下载完成后内容才真正落到本地，此时必须让 `AvatarView` 重建并重新
/// 加载封面。把它作为 `.id(...)` 的值，是取代 kit 内部 `needsReload` 的机制。
struct AudioItemAvatarIdentity: Hashable {
    let id: URL
    let reloadToken: Int
}

/// 列表项头像：下载中显示进度环，其余时候显示封面。
///
/// ## 为什么独立成视图
///
/// `AudioList` 对每一行套了 `.equatable()`，而 `AudioItemView` 的相等判断只比较
/// `url`，因此**整行**不会因为下载进度变化而重算。进度环与封面重建都必须绕过这层
/// 短路，所以本视图直接观察 `CloudDownloadProgressStore`。
///
/// ## 为什么下载中用进度环「取代」封面，而不是叠在封面之上
///
/// 叠上去时，底下那一层渲染的并不是封面，而是 `AvatarView` 的错误态——iCloud
/// 文件在下载完成前本地并不存在，`AvatarView` 的初判把它当成「文件不存在」，于是
/// 画出一个红色感叹号。半透明的进度环压不住底下的红色，于是列表里出现了
/// 「进度环 + 红色感叹号」这自相矛盾的画面（正在下载的那一项尤其刺眼）。
///
/// 改成**取代**之后：下载中只画进度环；下载完成、封面就绪后再把位置让给封面。
///
/// ## 顺带修好的问题：下载完成后封面不出现
///
/// 重建标记原先在 `AudioItemView` 的 body 里读取，而整行被 `.equatable()` 短路，
/// 下载完成并不会让 body 重算，`.id(...)` 始终是旧值——封面因此一直不刷新，
/// 要等这一行被重建（滚动出视野再回来、列表重载）才会更新。标记挪进本视图后，
/// 它直接观察进度容器，完成计数一变化就会换新 id。
struct AudioItemAvatarView: View {
    /// 进度状态源；直接观察它即可获得更新，无需父视图传值。
    @ObservedObject private var store: CloudDownloadProgressStore

    let url: URL
    let size: CGSize
    let backgroundColor: Color
    let verbose: Bool

    init(
        store: CloudDownloadProgressStore,
        url: URL,
        size: CGSize = CGSize(width: 40, height: 40),
        backgroundColor: Color = .blue.opacity(0.1),
        verbose: Bool = false
    ) {
        self.store = store
        self.url = url
        self.size = size
        self.backgroundColor = backgroundColor
        self.verbose = verbose
    }

    /// 当前下载进度；`nil` 表示没有进行中的下载（此时显示封面）。
    private var activeProgress: Double? {
        AudioItemAvatarPolicy.activeProgress(store.progress(for: url) { 1 })
    }

    /// 缩略图重载次数；下载完成一次即换新 id，强制重建 `AvatarView` 重载封面。
    private var reloadToken: Int {
        store.reloadToken(for: url)
    }

    var body: some View {
        if let activeProgress {
            AudioDownloadProgressRing(
                progress: activeProgress,
                size: size,
                backgroundColor: backgroundColor
            )
        } else {
            url.makeAvatarView(verbose: verbose)
                .magicSize(size)
                .magicAvatarShape(.circle)
                .magicBackground(backgroundColor)
                .magicDownloadMonitor(false)
                // `.id(...)` 必须放在最后：它会把视图擦除为 `some View`，
                // 放在链首会让后续 `magic*` 修饰符失去 `AvatarView` 类型。
                .id(AudioItemAvatarIdentity(id: url, reloadToken: reloadToken))
        }
    }
}

/// 头像呈现策略：哪些进度值算「进行中的下载」。
enum AudioItemAvatarPolicy {
    /// 只有 `0 < progress < 1` 才是进行中的下载。
    ///
    /// `0` 表示没有下载记录，`1` 表示已经完成——两者都要把位置让给封面。
    static func activeProgress(_ value: Double) -> Double? {
        guard value > 0, value < 1 else { return nil }
        return value
    }
}

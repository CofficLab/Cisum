import Combine
import MagicKit
import OSLog
import SwiftUI

/// iCloud 下载进度环。
///
/// **独立观察 `CloudDownloadProgressStore`，不参与 `AudioList` 对整行的
/// `.equatable()` 短路**：`AudioItemView` 的相等判断只比较 `url`，因此任何经由
/// `AudioListViewModel` 传入的进度都会被判为「无变化」而丢弃。本视图改为直接订阅
/// 进度容器，绕开该短路。
///
/// 覆盖在头像之上：下载进行中时取代封面显示进度，完成后自动让位给封面。
struct AudioDownloadProgressRing: View {
    /// 进度状态源；直接观察它即可获得更新，无需父视图传值。
    @ObservedObject private var store: CloudDownloadProgressStore
    private let url: URL
    private let size: CGSize
    private let backgroundColor: Color

    /// 当前进度；`nil` 表示该文件没有进行中的下载（此时不渲染任何内容）。
    private var progress: Double? {
        let value = store.progress(for: url) { 1 }
        guard value > 0, value < 1 else { return nil }
        return value
    }

    init(
        store: CloudDownloadProgressStore,
        url: URL,
        size: CGSize = CGSize(width: 40, height: 40),
        backgroundColor: Color = .blue.opacity(0.1)
    ) {
        self.store = store
        self.url = url
        self.size = size
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        if let progress {
            ring(progress: progress)
        }
    }

    private func ring(progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(size.width * 0.1)
        .frame(width: size.width, height: size.height)
        .background(backgroundColor)
        .clipShape(Circle())
        // 无障碍契约与 MagicKit 原实现保持一致，UI 测试与辅助功能依赖该标识。
        .accessibilityIdentifier("cisum.avatar.download.progress")
        .accessibilityValue(Text("\(Int(progress * 100))%"))
    }
}

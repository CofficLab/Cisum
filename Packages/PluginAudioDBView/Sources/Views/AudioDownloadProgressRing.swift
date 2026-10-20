import MagicKit
import OSLog
import SwiftUI

/// iCloud 下载进度环。
///
/// **取代封面显示进度，而不是叠在封面之上**：iCloud 文件在下载完成前本地并不存在，
/// `AvatarView` 此时渲染的是错误态（红色感叹号），半透明的进度环压不住底下那层
/// 红色，列表里就会出现「进度环 + 红色感叹号」这种自相矛盾的画面。改由
/// `AudioItemAvatarView` 在下载期间**只**渲染本视图，下载完成后再让位给封面。
///
/// 进度值由调用方给出（`AudioItemAvatarView` 直接观察进度容器后传入），
/// 因此本视图不再自行订阅，也不参与 `AudioList` 对整行的 `.equatable()` 短路。
struct AudioDownloadProgressRing: View {
    /// 下载进度，范围 `0...1`。
    let progress: Double
    let size: CGSize
    let backgroundColor: Color

    init(
        progress: Double,
        size: CGSize = CGSize(width: 40, height: 40),
        backgroundColor: Color = .blue.opacity(0.1)
    ) {
        self.progress = progress
        self.size = size
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        ring(progress: progress)
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

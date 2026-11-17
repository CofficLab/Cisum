import MagicPlayMan
import SwiftUI

/// 有声书控制区进度条：章节播放进度与拖动定位。
///
/// 与音乐场景的进度条同形但独立实现：布尔值/下载态都由本书籍插件自己的
/// ViewModel 提供，不依赖音乐侧的进度插件。
struct BookProgressBarView: View {
    @ObservedObject private var viewModel: BookProgressBarViewModel

    init(viewModel: BookProgressBarViewModel) {
        self.viewModel = viewModel
    }

    private func makeCurrentTimeBinding() -> Binding<TimeInterval> {
        Binding(
            get: { viewModel.currentTime },
            set: { viewModel.handleTimeChanged($0) }
        )
    }

    var body: some View {
        Group {
            if let downloadProgress = viewModel.downloadProgress {
                BookDownloadProgressBar(progress: downloadProgress)
            } else {
                MagicProgressBar(
                    currentTime: makeCurrentTimeBinding(),
                    duration: viewModel.duration,
                    onSeek: { viewModel.seek(to: $0) }
                )
            }
        }
        .accessibilityIdentifier("cisum.player.book.progress")
    }
}

/// 下载态进度条：不可拖动，右侧标注百分比。
private struct BookDownloadProgressBar: View {
    let progress: Double

    var body: some View {
        HStack(spacing: 8) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)

            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .fixedSize()
        }
        .accessibilityIdentifier("cisum.player.book.progress.download")
        .accessibilityValue(Text("\(Int(progress * 100))%"))
    }
}

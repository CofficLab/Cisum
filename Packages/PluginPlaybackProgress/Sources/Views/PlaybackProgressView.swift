import MagicPlayMan
import SwiftUI

/// 播放器控制区进度条视图：自观察播放进度，支持实时更新与拖动控制。
///
/// 当播放状态为下载中（`downloadProgress != nil`）时，自动切换为下载进度条，
/// 显示下载百分比而非播放时间。下载完成后自动恢复为播放进度条。
struct PlaybackProgressView: View {
    @ObservedObject private var viewModel: PlaybackProgressViewModel

    init(viewModel: PlaybackProgressViewModel) {
        self.viewModel = viewModel
    }

    func makeCurrentTimeBinding() -> Binding<TimeInterval> {
        Binding(
            get: { viewModel.currentTime },
            set: { viewModel.handleTimeChanged($0) }
        )
    }

    func handleSeek(_ time: TimeInterval) {
        viewModel.seek(to: time)
    }

    var body: some View {
        Group {
            if let downloadProgress = viewModel.downloadProgress {
                // 下载态：显示下载进度条，不可拖动
                DownloadProgressBar(progress: downloadProgress)
            } else {
                // 正常态：显示播放进度条
                MagicProgressBar(
                    currentTime: makeCurrentTimeBinding(),
                    duration: viewModel.duration,
                    onSeek: handleSeek
                )
            }
        }
        .accessibilityIdentifier("cisum.player.progress")
    }
}

// MARK: - 下载进度条

/// 下载进度条：不可拖动的进度指示器，显示下载百分比。
///
/// 造型与播放进度条保持视觉一致（同样高度的滑块轨道），但用 `ProgressView`
/// 替代 `Slider`，避免用户误操作拖动。右侧标注百分比。
private struct DownloadProgressBar: View {
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
        .accessibilityIdentifier("cisum.player.progress.download")
        .accessibilityValue(Text("\(Int(progress * 100))%"))
    }
}

import CisumUIComponents
import SwiftUI

/// 播放器控制区进度条视图：自观察播放进度，支持实时更新与拖动控制。
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
        MagicProgressBar(
            currentTime: makeCurrentTimeBinding(),
            duration: viewModel.duration,
            onSeek: handleSeek
        )
    }
}

import SwiftUI

/// 视频进度条：位置 / 时长 + 可拖动的进度滑杆。
struct VideoProgressView: View {
    @ObservedObject var viewModel: VideoLibraryViewModel
    var isImmersive = false
    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0

    var body: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubValue : viewModel.progress },
                    set: { scrubValue = $0 }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    isScrubbing = editing
                    if !editing {
                        viewModel.seek(to: viewModel.duration * scrubValue)
                    }
                }
            )
            .tint(isImmersive ? .white : nil)
            .disabled(viewModel.duration <= 0)

            HStack {
                Text(timeText(viewModel.currentTime))
                Spacer()
                Text(timeText(viewModel.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(isImmersive ? Color.white.opacity(0.75) : Color.secondary)
        }
        .accessibilityIdentifier("cisum.video.progress")
    }

    private func timeText(_ value: TimeInterval) -> String {
        guard value.isFinite, value > 0 else { return "0:00" }
        let total = Int(value.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

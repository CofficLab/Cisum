import LumiUI
import SwiftUI

/// 有声书载入横幅：替代状态行与进度行，说明「谁、在做什么、能否取消/重试」。
///
/// 高度与它替代的两行保持一致（由 `ControlView` 决定），因此切换载入态
/// 不会引起控制区跳动；失败态的引擎原始原因只进入 tooltip 与无障碍提示，
/// 正文始终使用可行动的人话。
struct BookLoadingBanner: View {
    @ObservedObject private var viewModel: BookLoadingViewModel
    @LumiTheme private var theme

    init(viewModel: BookLoadingViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Group {
            switch viewModel.mode {
            case .hidden:
                EmptyView()
            case .downloading(let progress):
                downloadingRow(progress)
            case .failed(let detail):
                failedRow(detail)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cisum.player.loading")
    }

    // MARK: - Downloading

    private func downloadingRow(_ progress: Double?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.callout)
                    .foregroundStyle(theme.primary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Loading from iCloud", bundle: .module)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                        .accessibilityIdentifier("cisum.player.loading.title")

                    if !viewModel.subject.isEmpty {
                        Text(viewModel.subject)
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .accessibilityIdentifier("cisum.player.loading.subject")
                    }
                }

                Spacer(minLength: 8)

                if let progress {
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                        .accessibilityIdentifier("cisum.player.loading.progress")
                } else {
                    ProgressView()
                        .controlSize(.mini)
                        .accessibilityIdentifier("cisum.player.loading.progress")
                        .accessibilityLabel(Text("Loading", bundle: .module))
                }

                Button {
                    viewModel.cancel()
                } label: {
                    Text("Cancel", bundle: .module)
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("cisum.player.loading.cancel")
                .accessibilityLabel(Text("Cancel loading \(viewModel.subject)", bundle: .module))
                .accessibilityHint(Text(
                    "The iCloud transfer may continue in the background.",
                    bundle: .module
                ))
            }

            track(progress)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func track(_ progress: Double?) -> some View {
        if let progress {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.elevatedSurface)
                    Capsule()
                        .fill(theme.primary)
                        .frame(width: max(2, geometry.size.width * progress))
                }
            }
            .frame(height: 3)
        } else {
            ProgressView()
                .progressViewStyle(.linear)
                .controlSize(.mini)
        }
    }

    // MARK: - Failed

    private func failedRow(_ detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.icloud.fill")
                .font(.callout)
                .foregroundStyle(theme.error)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Couldn't load from iCloud", bundle: .module)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .accessibilityIdentifier("cisum.player.loading.error")
                    .accessibilityHint(Text(verbatim: detail))

                Text("Check your connection and try again.", bundle: .module)
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .accessibilityIdentifier("cisum.player.loading.help")
            }

            Spacer(minLength: 8)

            Button {
                viewModel.retry()
            } label: {
                Text("Retry", bundle: .module)
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("cisum.player.loading.retry")
        }
        .help(Text(verbatim: detail))
    }
}

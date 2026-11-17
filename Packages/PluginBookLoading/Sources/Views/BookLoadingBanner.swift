import LumiUI
import SwiftUI

/// 有声书载入横幅：替代状态行与进度行，说明「谁、在做什么、能否取消/重试」。
///
/// 造型与 `docs/ux/audiobook-download-states.html` 的原型一致：一张轻卡片，
/// 标题行给出动作与百分比，第二行给出书名与章节位置，底部是进度与出口。
/// 高度仍由控制区按「状态行 + 进度行」分配，因此激活横幅不会让控制区跳动；
/// 高度不足时依次收起说明行，保证标题、进度与取消始终可读。
/// 失败态的引擎原始原因只进入 tooltip 与无障碍提示，正文始终是可行动的人话。
struct BookLoadingBanner: View {
    @ObservedObject private var viewModel: BookLoadingViewModel
    @LumiTheme private var theme

    init(viewModel: BookLoadingViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                switch viewModel.mode {
                case .hidden:
                    EmptyView()
                case .downloading(let progress):
                    downloadingCard(progress, height: geometry.size.height)
                case .failed(let detail):
                    failedCard(detail, height: geometry.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cisum.player.loading")
    }

    // MARK: - Downloading

    private func downloadingCard(_ progress: Double?, height: CGFloat) -> some View {
        let showsFooter = height >= 78
        let isCompact = height < 70
        let verticalPadding: CGFloat = isCompact ? 6 : 8

        return VStack(alignment: .leading, spacing: isCompact ? 2 : 3) {
            HStack(spacing: 7) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.primary)
                    .accessibilityHidden(true)

                Text("Loading from iCloud", bundle: .module)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .accessibilityIdentifier("cisum.player.loading.title")

                Spacer(minLength: 8)

                if let progress {
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(size: 12.5, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(theme.primary)
                        .fixedSize()
                        .accessibilityIdentifier("cisum.player.loading.progress")
                } else {
                    ProgressView()
                        .controlSize(.mini)
                        .accessibilityIdentifier("cisum.player.loading.progress")
                        .accessibilityLabel(Text("Loading", bundle: .module))
                }

                if !showsFooter {
                    cancelButton
                }
            }

            subjectLine

            Spacer(minLength: 0)

            track(progress)

            if showsFooter {
                HStack {
                    Text("Not cached on this device yet; you can listen offline once it finishes.", bundle: .module)
                        .font(.system(size: 10.5))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 8)

                    cancelButton
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .appSurface(style: .glass, cornerRadius: 12, borderColor: theme.divider, lineWidth: 1)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
    }

    private var cancelButton: some View {
        Button {
            viewModel.cancel()
        } label: {
            Text("Cancel", bundle: .module)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(theme.primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cisum.player.loading.cancel")
        .accessibilityLabel(Text("Cancel loading \(viewModel.subject.fallbackTitle)", bundle: .module))
        .accessibilityHint(Text(
            "The iCloud transfer may continue in the background.",
            bundle: .module
        ))
        .help(Text("Cancel", bundle: .module))
    }

    @ViewBuilder
    private func track(_ progress: Double?) -> some View {
        if let progress {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.textSecondary.opacity(0.16))
                    Capsule()
                        .fill(theme.primary)
                        .frame(width: max(3, geometry.size.width * progress))
                        .animation(.easeOut(duration: 0.25), value: progress)
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)
        } else {
            ProgressView()
                .progressViewStyle(.linear)
                .controlSize(.mini)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Failed

    private func failedCard(_ detail: String, height: CGFloat) -> some View {
        let showsHint = height >= 78
        let isCompact = height < 70
        let verticalPadding: CGFloat = isCompact ? 6 : 8
        let retryHeight: CGFloat = showsHint ? 25 : 20

        return VStack(alignment: .leading, spacing: isCompact ? 2 : 3) {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.icloud.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.error)
                    .accessibilityHidden(true)

                Text("Couldn't load · iCloud unavailable", bundle: .module)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .accessibilityIdentifier("cisum.player.loading.error")
                    .accessibilityHint(Text(verbatim: detail))

                Spacer(minLength: 8)

                Button {
                    viewModel.retry()
                } label: {
                    Text("Retry", bundle: .module)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: retryHeight)
                        .background(theme.error, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cisum.player.loading.retry")
            }

            subjectLine

            if showsHint {
                Text("Cached chapters still play. You can retry this one later.", bundle: .module)
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityIdentifier("cisum.player.loading.help")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .appSurface(
            style: .custom(theme.error.opacity(0.12)),
            cornerRadius: 12,
            borderColor: theme.error.opacity(0.32),
            lineWidth: 1
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
        .help(Text(verbatim: detail))
    }

    // MARK: - Subject

    @ViewBuilder
    private var subjectLine: some View {
        let subject = viewModel.subject
        if !subject.isEmpty {
            subjectText(subject)
                .font(.system(size: 11.5))
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityIdentifier("cisum.player.loading.subject")
        }
    }

    private func subjectText(_ subject: BookLoadingSubject) -> Text {
        guard !subject.bookTitle.isEmpty else {
            return Text(verbatim: subject.chapterTitle)
                .foregroundColor(theme.textSecondary)
        }

        let quotedTitle = String(
            format: String(localized: "《%@》", bundle: .module),
            subject.bookTitle
        )
        var line = Text(verbatim: quotedTitle)
            .fontWeight(.bold)
            .foregroundColor(theme.textPrimary)

        if let position = subject.chapterPosition {
            let label = String(
                format: String(localized: "Chapter %lld of %lld", bundle: .module),
                position.index,
                position.count
            )
            line = line + Text(verbatim: "  ") + Text(verbatim: label)
                .foregroundColor(theme.textSecondary)
        }

        return line
    }
}
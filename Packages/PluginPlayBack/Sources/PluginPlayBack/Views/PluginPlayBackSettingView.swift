import CisumUIComponents
import ProviderPlayback
import ProviderScene
import SwiftUI

/// 播放设置页：按场景区分展示「当前文件」。
///
/// 内核存在场景概念（`AppScene` 固定枚举，如「音乐库」「有声书」），因此本页
/// 不再只展示单一全局当前文件：
/// - 「各场景最近播放」：每个场景一行，展示该场景最近播放的文件，当前激活场景
///   带「当前」标记并高亮；场景切换由 `PlaybackSettingsSceneObserver` 驱动刷新。
/// - 「播放详情」：当前场景的活动播放状态，随播放引擎实时刷新
///   （`currentURL` / `isPlaying` / `duration` / `currentTime`）。
struct PluginPlayBackSettingView: View {
    @ObservedObject private var viewModel: PluginPlayBackSettingsViewModel
    @LumiTheme private var theme

    init(viewModel: PluginPlayBackSettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        AppSettingsContentScaffold(scrollsContent: true, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 16) {
                header
                sceneSection
                playbackSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Spacer()
            if let scene = viewModel.currentScene {
                Text(scene.displayName)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            if viewModel.currentURL != nil {
                Text(viewModel.isPlaying ? "Playing" : "Paused")
                    .font(.appCaption)
                    .foregroundStyle(viewModel.isPlaying ? theme.success : .secondary)
            }
        }
    }

    private var sceneSection: some View {
        AppSettingsSection(title: "Recent Playback by Scene") {
            ForEach(viewModel.scenes) { scene in
                sceneRow(scene)
            }
        }
    }

    private func sceneRow(_ scene: AppScene) -> some View {
        AppSettingsRow(isSelected: scene == viewModel.currentScene) {
            HStack(spacing: 12) {
                Image(systemName: scene.iconName)
                    .foregroundStyle(theme.primary)
                    .frame(width: 22)
                Text(scene.displayName)
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                if scene == viewModel.currentScene {
                    Text("Current")
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(theme.textTertiary.opacity(0.15)))
                }
                Text(fileName(for: scene) ?? "No Record")
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var playbackSection: some View {
        AppSettingsSection(title: "Playback Details") {
            if viewModel.currentURL != nil {
                infoCard
            } else {
                emptyState
            }
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            row(icon: "music.note", title: String(localized: "File Name", bundle: .module), value: viewModel.currentURL?.lastPathComponent ?? "—")
            row(icon: "folder", title: String(localized: "Path", bundle: .module), value: viewModel.currentURL?.deletingLastPathComponent().path ?? "—")
            row(icon: "internaldrive", title: String(localized: "Size", bundle: .module), value: fileSizeText)
            row(icon: "timer", title: String(localized: "Duration", bundle: .module), value: Self.formatTime(viewModel.duration))
            row(icon: "clock", title: String(localized: "Played", bundle: .module), value: Self.formatTime(viewModel.currentTime))
            row(icon: "play.circle", title: String(localized: "Status", bundle: .module), value: viewModel.state.description)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.background)
                .strokeBorder(theme.divider, lineWidth: 1)
        )
    }

    private func row(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(theme.primary)
                .frame(width: 20)
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Spacer(minLength: 12)
            Text(value)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.appBody)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "play.circle")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("No file is currently playing")
                .font(.appBody)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func fileName(for scene: AppScene) -> String? {
        viewModel.lastFile(for: scene)?.lastPathComponent
    }

    private var fileSizeText: String {
        guard let url = viewModel.currentURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return "—"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private static func formatTime(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private extension PlaybackStatus {
    /// 播放状态的中文展示名。
    var description: String {
        switch self {
        case .idle: String(localized: "Idle", bundle: .module)
        case .loading: String(localized: "Loading", bundle: .module)
        case .willPlay: String(localized: "Ready to Play", bundle: .module)
        case .playing: String(localized: "Playing", bundle: .module)
        case .paused: String(localized: "Paused", bundle: .module)
        case .stopped: String(localized: "Stopped", bundle: .module)
        case .failed: String(localized: "Failed", bundle: .module)
        @unknown default: String(localized: "Unknown", bundle: .module)
        }
    }
}

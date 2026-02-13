import MagicKit
import MagicPlayMan
import OSLog
import SwiftData
import SwiftUI

struct StateView: View, SuperLog, SuperThread {
    @EnvironmentObject var app: AppProvider
    @EnvironmentObject var messageManager: StateProvider
    @EnvironmentObject var playMan: PlayMan
    @EnvironmentObject var p: PluginProvider
    @Environment(\.demoMode) var isDemoMode

    nonisolated static let emoji = "🖥️"
    nonisolated static let verbose = false

    var asset: URL? { playMan.asset }
    var font: Font { asset == nil ? .title3 : .callout }

    var body: some View {
        if isDemoMode {
            EmptyView()
        } else {
            VStack(spacing: 10) {
                // 内部状态消息
                if messageManager.stateMessage.count > 0 {
                    makeInfoView(messageManager.stateMessage)
                }

                if playMan.state.isDownloading {
                    makeInfoView(playMan.state.localizedStateText(localization: playMan.localization))
                }

                // 播放过程中出现的错误
                if let e = playMan.currentError {
                    makeErrorView(e)
                }

                // 各个插件提供的 state view
                ForEach(p.plugins, id: \.id) { plugin in
                    plugin.addStateView(currentSceneName: p.currentSceneName)
                }
            }
        }
    }
}

// MARK: - View

extension StateView {
    func makeInfoView(_ i: String) -> some View {
        HStack {
            Image.info
                .foregroundStyle(.white)
            Text(i)
                .foregroundStyle(.white)
        }
        .font(font)
        .inCard()
    }

    func makeErrorView(_ e: Error) -> some View {
        HStack {
            Image.info
                .foregroundStyle(.white)
            // 如果是 PlaybackError，使用本地化描述
            if let playbackError = e as? PlaybackState.PlaybackError {
                Text(playbackError.localizedDescription(localization: playMan.localization))
                    .foregroundStyle(.white)
            } else {
                Text(e.localizedDescription)
                    .foregroundStyle(.white)
            }
        }
        .font(font)
        .inCard()
    }
}

// MARK: - Action

extension StateView {
}

// MARK: - Setter

extension StateView {
}

// MARK: - Event Handler

extension StateView {
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

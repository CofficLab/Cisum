import Foundation
import MagicKit
import OSLog
import SwiftUI

struct AudioDBRootView<Content>: View, SuperLog where Content: View {
    nonisolated static var emoji: String { "🎵" }
    nonisolated static var verbose: Bool { false }

    @EnvironmentObject var app: AppProvider
    @Environment(\.demoMode) var isDemoMode

    private var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if isDemoMode {
            content
        } else {
            content
                .task {
                    await checkAudioRepo()
                }
                .onDBUpdated(perform: handleDBUpdated)
        }
    }
}

// MARK: - Private Helpers

extension AudioDBRootView {
    /// 检查 AudioRepo 是否为空，如果为空则显示数据库视图
    @MainActor
    private func checkAudioRepo() async {
        guard !isDemoMode else { return }

        guard let repo = AudioPlugin.getAudioRepo() else {
            app.showDBView()
            return
        }

        let count = await repo.getTotalCount()
        
        if count == 0 {
            app.showDBView()
        }
    }
}

// MARK: - Event Handler

extension AudioDBRootView {
    /// 处理数据库更新事件
    func handleDBUpdated(_ notification: Notification) {
        Task {
            await checkAudioRepo()
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

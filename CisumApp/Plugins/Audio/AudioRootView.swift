import Foundation
import MagicAlert
import MagicKit
import MagicPlayMan
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AudioRootView<Content>: View, SuperLog where Content: View {
    nonisolated static var emoji: String { "📢" }
    nonisolated static var verbose: Bool { false }

    @EnvironmentObject var man: PlayMan
    @EnvironmentObject var p: PluginProvider
    @EnvironmentObject var app: AppProvider

    @State private var error: AudioPluginError? = nil
    private var content: Content

    var container: ModelContainer?
    var repo: AudioRepo?

    init(@ViewBuilder content: () -> Content) {
        if Self.verbose {
            os_log("\(Self.t)初始化开始")
        }

        self.content = content()
        guard let container = try? AudioConfigRepo.getContainer() else {
            self.error = AudioPluginError.initialization(reason: "Container 未找到")
            os_log(.error, "\(Self.t)初始化失败: Container 未找到")
            return
        }

        self.container = container

        let storage = Config.getStorageLocation()

        guard storage != nil else {
            self.error = AudioPluginError.initialization(reason: "Storage 未找到")
            if Self.verbose {
                os_log("\(Self.t)放弃初始化，因为: Storage 未找到")
            }
            return
        }

        self.container = try? AudioConfigRepo.getContainer()

        if Self.verbose {
            os_log("\(Self.t)初始化完成")
        }
    }

    var body: some View {
        Group {
            if let container = self.container {
                ZStack {
                    content
                }
                .modelContainer(container)
                .onStorageLocationChanged(perform: handleStorageLocationChanged)
                .onDisappear(perform: handleOnDisappear)
            } else {
                storageErrorView
            }
        }
    }

    // MARK: - Error View

    private var storageErrorView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("存储位置未设置", tableName: "Audio")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text("请先设置媒体仓库的存储位置", tableName: "Audio")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Event Handler

extension AudioRootView {
    /// 处理存储位置变化事件
    ///
    /// 当用户切换存储位置（本地/iCloud）时触发，提示用户存储位置已变化。
    func handleStorageLocationChanged() {
        if Self.verbose {
            os_log("\(self.t)📂 存储位置已变化")
        }

        alert_info("存储位置发生了变化")
    }

    /// 处理视图消失事件
    ///
    /// 当视图从屏幕上消失时触发，用于清理资源。
    func handleOnDisappear() {
        if Self.verbose {
            os_log("\(self.t)👋 视图已消失")
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

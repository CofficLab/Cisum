import Foundation
import MagicKit
import OSLog
import SwiftData
import SwiftUI

#if os(macOS)
    actor CopyPlugin: SuperPlugin, SuperLog {
        static let emoji = "🚛"
        static let verbose = true
        static var shouldRegister: Bool { true }
        static var order: Int { 0 }
        @MainActor static var worker: CopyWorker? = nil
        @MainActor static var db: CopyDB? = nil
        @MainActor static var container: ModelContainer? = nil

        let description: String = "在后台复制文件，注意仅用于macOS"
        let iconName: String = "music.note"

        @MainActor func addStateView(currentSceneName: String?) -> AnyView? {
            return AnyView(
                CopyStateView()
            )
        }

        @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
            return AnyView(
                CopyRootView { content() }
            )
        }

        /// 获取或创建 Worker
        /// - Returns: CopyWorker 实例，如果创建失败则返回 nil
        @MainActor static func getWorker() -> CopyWorker? {
            if let worker = Self.worker {
                return worker
            }

            // 首次调用时初始化
            if let db = Self.getDB() {
                Self.worker = CopyWorker(db: db, reason: "AudioCopyPlugin")
            }
            
            return Self.worker
        }

        /// 获取 CopyDB 实例
        /// - Returns: CopyDB 实例，如果获取失败则返回 nil
        @MainActor static func getDB() -> CopyDB? {
            if let db = Self.db {
                return db
            }

            if let container = try? Self.getContainer() {
                let db = CopyDB(container, reason: "AudioCopyPlugin", verbose: false)
                Self.db = db
                return db
            }

            return nil
        }

        /// 获取复制任务的 ModelContainer
        /// - Returns: 配置好的 ModelContainer
        /// - Throws: 如果创建失败则抛出错误
        @MainActor static func getContainer() throws -> ModelContainer {
            if let container = Self.container {
                return container
            }

            let url = try Config.createDatabaseFile(name: "copy_db")

            let schema = Schema([
                CopyTask.self,
            ])

            let modelConfiguration = ModelConfiguration(
                schema: schema,
                url: url,
                allowsSave: true,
                cloudKitDatabase: .none
            )

            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            Self.container = container
            return container
        }

        /// 检查是否超出音频数量限制
        /// - Returns: 如果超出限制则返回 true，否则返回 false
        @MainActor static func isOutOfLimit() async -> Bool {
            guard let repo = AudioPlugin.getAudioRepo() else {
                return false
            }
            let count = await repo.getTotalCount()
            return count >= AudioPlugin.maxAudioCount && StoreService.tierCached().isFreeVersion
        }
    }
#endif

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

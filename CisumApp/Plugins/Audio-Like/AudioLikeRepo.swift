import Foundation
import OSLog
import SwiftData
import SwiftUI

actor AudioLikeRepo: SuperLog {
    static let emoji = "💖"
    static let verbose = false

    /// 单例实例
    static let shared = AudioLikeRepo()

    /// SwiftData 模型容器
    @MainActor
    private var container: ModelContainer?

    private init() {
        Task { @MainActor in
            do {
                let schema = Schema([AudioLikeModel.self])
                let modelConfiguration = ModelConfiguration(
                    schema: schema,
                    url: try Config.createDatabaseFile(name: "audio_like"),
                    allowsSave: true,
                    cloudKitDatabase: .none
                )
                self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                os_log(.error, "\(self.t)❌ 初始化 AudioLikeRepo 失败: \(error.localizedDescription)")
            }
        }
    }

    /// 获取模型上下文
    @MainActor
    private var context: ModelContext? {
        container?.mainContext
    }

    /// 检查指定音频是否被喜欢
    /// - Parameter audioId: 音频唯一标识符
    /// - Returns: 是否喜欢
    @MainActor
    func isLiked(audioId: String) async -> Bool {
        guard let context = self.context else { return false }

        do {
            let descriptor = AudioLikeModel.descriptorOf(audioId: audioId)
            let results = try context.fetch(descriptor)
            return results.first?.liked ?? false
        } catch {
            os_log(.error, "\(self.t)❌ 检查喜欢状态失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 检查指定 URL 的音频是否被喜欢
    /// - Parameter url: 音频 URL
    /// - Returns: 是否喜欢
    func isLiked(url: URL) async -> Bool {
        let audioId = url.absoluteString
        return await isLiked(audioId: audioId)
    }

    /// 查找喜欢状态模型
    /// - Parameter audioId: 音频唯一标识符
    /// - Returns: 喜欢状态模型，如果不存在返回 nil
    @MainActor
    func findLikeModel(audioId: String) async throws -> AudioLikeModel? {
        guard let context = self.context else { return nil }

        let descriptor = AudioLikeModel.descriptorOf(audioId: audioId)
        let results = try context.fetch(descriptor)
        return results.first
    }

    /// 保存喜欢状态模型
    /// - Parameter model: 要保存的模型
    @MainActor
    func save(_ model: AudioLikeModel) async throws {
        guard let context = self.context else {
            throw AudioLikeRepoError.containerNotAvailable
        }

        context.insert(model)
        try context.save()
    }

    /// 更新喜欢状态
    /// - Parameters:
    ///   - audioId: 音频唯一标识符
    ///   - liked: 是否喜欢
    func updateLikeStatus(audioId: String, liked: Bool) async throws {
        try await AudioLikeRepo.performOnMainActor {
            if let existingModel = try await self.findLikeModel(audioId: audioId) {
                existingModel.liked = liked
                existingModel.updatedAt = Date()
                try await self.save(existingModel)
            } else {
                // 创建新记录
                let newModel = AudioLikeModel(audioId: audioId, url: nil, liked: liked)
                try await self.save(newModel)
            }
        }
    }

    /// 在主 actor 上执行操作的辅助方法
    @MainActor
    private static func performOnMainActor<T>(_ operation: @MainActor () async throws -> T) async throws -> T {
        try await operation()
    }

    /// 获取所有喜欢的音频
    /// - Returns: 喜欢状态模型数组
    @MainActor
    func getAllLiked() async -> [AudioLikeModel] {
        guard let context = self.context else { return [] }

        do {
            let results = try context.fetch(AudioLikeModel.descriptorLiked)
            return results
        } catch {
            os_log(.error, "\(self.t)❌ 获取喜欢列表失败: \(error.localizedDescription)")
            return []
        }
    }

    /// 删除喜欢状态记录
    /// - Parameter audioId: 音频唯一标识符
    @MainActor
    func removeLikeStatus(audioId: String) async throws {
        guard let context = self.context else { return }

        if let model = try await findLikeModel(audioId: audioId) {
            context.delete(model)
            try context.save()
        }
    }
}

// MARK: - Errors

enum AudioLikeRepoError: Error, LocalizedError {
    case containerNotAvailable

    var errorDescription: String? {
        switch self {
        case .containerNotAvailable:
            return "数据容器不可用"
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

import Foundation
import CisumUIComponents
import OSLog
import SwiftData

public enum AudioLikeRepoError: Error, LocalizedError {
    case containerNotAvailable
    case databaseURLNotConfigured

    public var errorDescription: String? {
        switch self {
        case .containerNotAvailable:
            return String(localized: "Data container is unavailable", bundle: .module)
        case .databaseURLNotConfigured:
            return String(localized: "AudioLike database path is not configured", bundle: .module)
        }
    }
}

@MainActor
public enum AudioLikeRepositoryConfiguration {
    private static var databaseURL: URL?

    public static func configure(databaseURL: URL) {
        let shouldResetContainer = Self.databaseURL != databaseURL
        Self.databaseURL = databaseURL

        if shouldResetContainer {
            AudioLikeRepo.shared.resetContainerForConfigurationChange()
        }
    }

    static func currentDatabaseURL() -> URL? {
        databaseURL
    }
}

public actor AudioLikeRepo: SuperLog {
    public static let emoji = "💖"
    public static let verbose = false

    public static let shared = AudioLikeRepo()

    @MainActor
    private var container: ModelContainer?

    private init() {}

    @MainActor
    fileprivate func resetContainerForConfigurationChange() {
        container = nil
    }

    @MainActor
    private var context: ModelContext? {
        get async throws {
            try await ensureContainer()
            return container?.mainContext
        }
    }

    @MainActor
    private func ensureContainer() async throws {
        guard container == nil else { return }
        guard let databaseURL = AudioLikeRepositoryConfiguration.currentDatabaseURL() else {
            throw AudioLikeRepoError.databaseURLNotConfigured
        }

        let schema = Schema([AudioLikeModel.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: databaseURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        container = try await Self.makeContainer(
            schema: schema,
            configuration: modelConfiguration
        )
    }

    /// SwiftData 容器初始化可能触发数据库文件创建和 schema 检查，
    /// 不应阻塞首次播放恢复或喜欢列表打开时的主线程。
    private nonisolated static func makeContainer(
        schema: Schema,
        configuration: ModelConfiguration
    ) async throws -> ModelContainer {
        try await Task.detached(priority: .utility) {
            try ModelContainer(for: schema, configurations: [configuration])
        }.value
    }

    @MainActor
    public func isLiked(audioId: String) async -> Bool {
        do {
            guard let context = try await self.context else { return false }
            let descriptor = AudioLikeModel.descriptorOf(audioId: audioId)
            let results = try context.fetch(descriptor)
            return results.first?.liked ?? false
        } catch {
            os_log(.error, "\(self.t)❌ 检查喜欢状态失败: \(error.localizedDescription)")
            return false
        }
    }

    @MainActor
    public func isLiked(url: URL) async -> Bool {
        do {
            return try await findLikeModel(audioId: url.absoluteString, url: url)?.liked ?? false
        } catch {
            os_log(.error, "\(self.t)❌ 检查喜欢状态失败: \(error.localizedDescription)")
            return false
        }
    }

    @MainActor
    public func findLikeModel(audioId: String) async throws -> AudioLikeModel? {
        try await findLikeModel(audioId: audioId, url: nil)
    }

    @MainActor
    private func findLikeModel(audioId: String, url: URL?) async throws -> AudioLikeModel? {
        guard let context = try await self.context else { return nil }

        let descriptor = AudioLikeModel.descriptorOf(audioId: audioId)
        let results = try context.fetch(descriptor)
        if let result = results.first {
            return result
        }

        guard let url else { return nil }
        return try context.fetch(AudioLikeModel.descriptorAll).first { model in
            guard let storedURL = model.url else { return false }
            return Self.representsSameFile(storedURL, url)
        }
    }

    @MainActor
    public func save(_ model: AudioLikeModel) async throws {
        guard let context = try await self.context else {
            throw AudioLikeRepoError.containerNotAvailable
        }

        if model.modelContext == nil {
            context.insert(model)
        }
        try context.save()
    }

    public func updateLikeStatus(audioId: String, liked: Bool, url: URL? = nil, title: String? = nil) async throws {
        try await AudioLikeRepo.performOnMainActor {
            if !liked {
                try await self.removeLikeStatus(audioId: audioId, url: url)
                return
            }

            if let existingModel = try await self.findLikeModel(audioId: audioId, url: url) {
                existingModel.liked = liked
                if let url {
                    existingModel.url = url
                }
                if let title {
                    existingModel.title = title
                }
                existingModel.updatedAt = Date()
                try await self.save(existingModel)
                try await self.removeDuplicateLikeModels(keeping: existingModel, matching: url)
            } else {
                let newModel = AudioLikeModel(audioId: audioId, url: url, title: title, liked: liked)
                try await self.save(newModel)
                try await self.removeDuplicateLikeModels(keeping: newModel, matching: url)
            }
        }
    }

    @MainActor
    private static func performOnMainActor<T>(_ operation: @MainActor () async throws -> T) async throws -> T {
        try await operation()
    }

    @MainActor
    public func getAllLiked() async -> [AudioLikeModel] {
        do {
            guard let context = try await self.context else { return [] }
            let results = try context.fetch(AudioLikeModel.descriptorLiked)
            return results
        } catch {
            os_log(.error, "\(self.t)❌ 获取喜欢列表失败: \(error.localizedDescription)")
            return []
        }
    }

    @MainActor
    public func removeLikeStatus(audioId: String) async throws {
        try await removeLikeStatus(audioId: audioId, url: nil)
    }

    @MainActor
    private func removeLikeStatus(audioId: String, url: URL?) async throws {
        guard let context = try await self.context else { return }

        let models = try context.fetch(AudioLikeModel.descriptorAll)
        var removed = false
        for model in models where model.audioId == audioId || Self.model(model, represents: url) {
            context.delete(model)
            removed = true
        }

        if removed {
            try context.save()
        }
    }

    @MainActor
    private func removeDuplicateLikeModels(keeping keptModel: AudioLikeModel, matching url: URL?) async throws {
        guard let context = try await self.context, let url else { return }

        let models = try context.fetch(AudioLikeModel.descriptorAll)
        var removed = false
        for model in models where model.persistentModelID != keptModel.persistentModelID && Self.model(model, represents: url) {
            context.delete(model)
            removed = true
        }

        if removed {
            try context.save()
        }
    }

    private static func model(_ model: AudioLikeModel, represents url: URL?) -> Bool {
        guard let storedURL = model.url, let url else { return false }
        return representsSameFile(storedURL, url)
    }

    private static func representsSameFile(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.isSameFileLocation(as: rhs)
    }
}

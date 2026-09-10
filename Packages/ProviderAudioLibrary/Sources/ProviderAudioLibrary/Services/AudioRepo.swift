import Combine
import Foundation
import CisumUIComponents
import OSLog
import ProviderAudioLike
import SwiftData
import SwiftUI

@preconcurrency import Combine

@MainActor
public class AudioRepo: ObservableObject, SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "🎵"
    public nonisolated static let verbose = true

    private var db: AudioDB
    private var disk: URL

    public convenience init(disk: URL, databaseURL: URL, reason: String) throws {
        let container = try AudioConfigRepo.getContainer(databaseURL: databaseURL)
        try self.init(container: container, disk: disk, reason: reason)
    }

    public init(container: ModelContainer, disk: URL, reason: String) throws {
        if Self.verbose {
            os_log("\(Self.i) with reason: 🐛 \(reason) 💾 with disk: \(disk.shortPath())")
        }

        self.db = AudioDB(container, reason: reason)
        self.disk = disk
    }

    public func getAll(reason: String) async -> [URL] {
        await self.db.allAudioURLs(reason: reason)
    }

    public func get(offset: Int, limit: Int, reason: String) async -> [URL] {
        await self.db.paginateAudioURLs(offset: offset, limit: limit, reason: reason)
    }

    public func changeRoot(url: URL) {
        if Self.verbose {
            os_log("\(Self.t)🍋 Change disk to \(url.title)")
        }

        self.updateDisk(url)
    }

    public func updateDisk(_ url: URL) {
        self.disk = url
    }

    public func delete(_ audio: AudioModel, verbose: Bool) async throws {
        try await deleteAudios([audio.url], verbose: verbose)
    }

    public func find(_ url: URL) async -> URL? {
        await db.hasAudio(url) ? url : nil
    }

    public func getFirst() async throws -> URL? {
        try await db.firstAudioURL()
    }

    public func getLast() async throws -> URL? {
        try await db.lastAudioURL()
    }

    public func getNextOf(_ url: URL?, verbose: Bool = false) async throws -> URL? {
        guard let url, await db.hasAudio(url) else { return nil }
        if let next = try await db.getNextAudioURLOf(url, verbose: verbose) {
            return next
        }
        return try await db.firstAudioURL()
    }

    public func getPrevOf(_ url: URL?, verbose: Bool = false) async throws -> URL? {
        guard let url, await db.hasAudio(url) else { return nil }
        if let previous = try await db.getPrevAudioURLOf(url, verbose: verbose) {
            return previous
        }
        return try await db.lastAudioURL()
    }

    public func getTotalCount() async -> Int {
        await db.getTotalOfAudio()
    }

    public func getStorageRoot() async -> URL {
        self.disk
    }

    public func isLiked(_ url: URL) async -> Bool {
        await AudioLikeRepo.shared.isLiked(url: url)
    }

    public func like(_ url: URL?, liked: Bool) async {
        guard let url = url else { return }

        do {
            let audioId = url.absoluteString
            try await AudioLikeRepo.shared.updateLikeStatus(
                audioId: audioId,
                liked: liked,
                url: url,
                title: url.lastPathComponent
            )

            if liked {
                os_log("\(self.t)👍 Like \(url.lastPathComponent)")
            } else {
                if Self.verbose {
                    os_log("\(self.t)😁 Cancel like \(url.lastPathComponent)")
                }
            }
        } catch {
            os_log(.error, "\(self.t)❌ 更新喜欢状态失败: \(error.localizedDescription)")
        }
    }

    public func sort(_ sticky: AudioModel?, reason: String) async {
        await db.sort(sticky?.url, reason: reason)
    }

    public func sort(_ url: URL?, reason: String) async {
        await db.sort(url, reason: reason)
    }

    public func sortRandom(_ sticky: AudioModel?, reason: String, verbose: Bool) async throws {
        try await db.sortRandom(sticky?.url, reason: reason, verbose: verbose)
    }

    public func sortRandom(_ url: URL?, reason: String, verbose: Bool) async throws {
        try await db.sortRandom(url, reason: reason, verbose: verbose)
    }

    /// 删除多个音频文件
    /// - Parameter urls: 要删除的音频文件 URL 数组
    /// - Parameter verbose: 是否输出详细日志
    public func deleteAudios(_ urls: [URL], verbose: Bool = false) async throws {
        if urls.count > 0 {
            try await db.deleteAudiosByURL(disk: disk, urls: urls, verbose: verbose)
        }
    }

    public func sync(_ items: [URL], verbose: Bool = false, isFirst: Bool) async {
        if isFirst {
            await db.initItems(items, verbose: verbose)
        } else {
            await db.syncWithUpdatedItems(items, verbose: verbose)
        }
    }
}

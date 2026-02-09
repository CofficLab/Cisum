import Combine
import Foundation
import MagicKit
import OSLog
import SwiftData
import SwiftUI

@preconcurrency import Combine

@MainActor
class AudioRepo: ObservableObject, SuperLog {
    nonisolated static let emoji = "🎵"
    nonisolated static let verbose = false

    private var db: AudioDB
    private var disk: URL

    init(disk: URL, reason: String) throws {
        if Self.verbose {
            os_log("\(Self.i) with reason: 🐛 \(reason) 💾 with disk: \(disk.shortPath())")
        }

        let container = try AudioConfigRepo.getContainer()
        self.db = AudioDB(container, reason: reason)
        self.disk = disk
    }

    func getAll(reason: String) async -> [URL] {
        await self.db.allAudioURLs(reason: reason)
    }

    func get(offset: Int, limit: Int, reason: String) async -> [URL] {
        await self.db.paginateAudioURLs(offset: offset, limit: limit, reason: reason)
    }

    func changeRoot(url: URL) {
        if Self.verbose {
            os_log("\(Self.t)🍋 Change disk to \(url.title)")
        }

        self.updateDisk(url)
    }

    func updateDisk(_ url: URL) {
        self.disk = url
    }

    func delete(_ audio: AudioModel, verbose: Bool) async throws {
        try self.disk.delete()
        try await db.deleteAudio(url: audio.url)
    }

    func find(_ url: URL) async -> URL? {
        await db.hasAudio(url) ? url : nil
    }

    func getFirst() async throws -> URL? {
        try await db.firstAudioURL()
    }

    func getNextOf(_ url: URL?, verbose: Bool = false) async throws -> URL? {
        try await db.getNextAudioURLOf(url, verbose: verbose)
    }

    func getPrevOf(_ url: URL?, verbose: Bool = false) async throws -> URL? {
        try await db.getPrevAudioURLOf(url, verbose: verbose)
    }

    func getTotalCount() async -> Int {
        await db.getTotalOfAudio()
    }

    func getStorageRoot() async -> URL {
        self.disk
    }

    func isLiked(_ url: URL) async -> Bool {
        await AudioLikeRepo.shared.isLiked(url: url)
    }

    func like(_ url: URL?, liked: Bool) async {
        guard let url = url else { return }

        do {
            let audioId = url.absoluteString
            try await AudioLikeRepo.shared.updateLikeStatus(audioId: audioId, liked: liked)

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

    func sort(_ sticky: AudioModel?, reason: String) async {
        await db.sort(sticky?.url, reason: reason)
    }

    func sort(_ url: URL?, reason: String) async {
        await db.sort(url, reason: reason)
    }

    func sortRandom(_ sticky: AudioModel?, reason: String, verbose: Bool) async throws {
        try await db.sortRandom(sticky?.url, reason: reason, verbose: verbose)
    }

    func sortRandom(_ url: URL?, reason: String, verbose: Bool) async throws {
        try await db.sortRandom(url, reason: reason, verbose: verbose)
    }

    /// 删除多个音频文件
    /// - Parameter urls: 要删除的音频文件 URL 数组
    /// - Parameter verbose: 是否输出详细日志
    func deleteAudios(_ urls: [URL], verbose: Bool = false) async {
        if urls.count > 0 {
            try? await db.deleteAudios(urls, verbose: verbose)
        }
    }

    func sync(_ items: [URL], verbose: Bool = false, isFirst: Bool) async {
        if isFirst {
            await db.initItems(items, verbose: verbose)
        } else {
            await db.syncWithUpdatedItems(items, verbose: verbose)
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

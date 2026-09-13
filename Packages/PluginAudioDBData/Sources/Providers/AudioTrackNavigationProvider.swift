import Foundation
import MagicKit
import OSLog
import ProviderAudioNavigation

/// 音频曲目导航能力的具体实现。
///
/// 公共 Provider 包只定义跨插件协议；仓库查询和数据源绑定属于数据层插件，
/// 因此实现放在本插件中，由插件入口负责组装和注册。
@MainActor
final class AudioTrackNavigationProvider: AudioTrackNavigationProviding, SuperLog {
    nonisolated static let emoji = "🎵"
    nonisolated static let verbose = false

    typealias AdjacentURLResolver = @MainActor @Sendable (URL?, Bool) async throws -> URL?
    typealias BoundaryURLResolver = @MainActor @Sendable () async throws -> URL?

    private let resolveNextURL: AdjacentURLResolver
    private let resolvePreviousURL: AdjacentURLResolver
    private let resolveFirstURL: BoundaryURLResolver
    private let resolveLastURL: BoundaryURLResolver

    init(
        nextURL: @escaping AdjacentURLResolver,
        previousURL: @escaping AdjacentURLResolver,
        firstURL: @escaping BoundaryURLResolver,
        lastURL: @escaping BoundaryURLResolver
    ) {
        self.resolveNextURL = nextURL
        self.resolvePreviousURL = previousURL
        self.resolveFirstURL = firstURL
        self.resolveLastURL = lastURL
        if Self.verbose {
            os_log("\(Self.t)🚩 AudioTrackNavigationProvider initialized")
        }
    }

    func nextURL(after current: URL?, verbose: Bool) async throws -> URL? {
        if Self.verbose {
            os_log("\(Self.t)➡️ Resolve next audio: current=\(current?.lastPathComponent ?? "<none>"), verbose=\(verbose)")
        }
        do {
            let result = try await resolveNextURL(current, verbose)
            logResult(result, direction: "next")
            return result
        } catch {
            logFailure(error, direction: "next")
            throw error
        }
    }

    func previousURL(before current: URL?, verbose: Bool) async throws -> URL? {
        if Self.verbose {
            os_log("\(Self.t)⬅️ Resolve previous audio: current=\(current?.lastPathComponent ?? "<none>"), verbose=\(verbose)")
        }
        do {
            let result = try await resolvePreviousURL(current, verbose)
            logResult(result, direction: "previous")
            return result
        } catch {
            logFailure(error, direction: "previous")
            throw error
        }
    }

    func firstURL() async throws -> URL? {
        if Self.verbose {
            os_log("\(Self.t)⏮️ Resolve first audio")
        }
        do {
            let result = try await resolveFirstURL()
            logResult(result, direction: "first")
            return result
        } catch {
            logFailure(error, direction: "first")
            throw error
        }
    }

    func lastURL() async throws -> URL? {
        if Self.verbose {
            os_log("\(Self.t)⏭️ Resolve last audio")
        }
        do {
            let result = try await resolveLastURL()
            logResult(result, direction: "last")
            return result
        } catch {
            logFailure(error, direction: "last")
            throw error
        }
    }

    private func logResult(_ result: URL?, direction: String) {
        guard Self.verbose else { return }
        if let result {
            os_log("\(Self.t)✅ Resolved \(direction) audio: \(result.lastPathComponent)")
        } else {
            os_log("\(Self.t)⚠️ No \(direction) audio was found")
        }
    }

    private func logFailure(_ error: Error, direction: String) {
        if Self.verbose {
            os_log(.error, "\(Self.t)❌ Failed to resolve \(direction) audio: \(error.localizedDescription)")
        }
    }
}

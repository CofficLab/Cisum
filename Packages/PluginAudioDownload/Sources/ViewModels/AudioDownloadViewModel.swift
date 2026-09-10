import Foundation
import MagicKit
import OSLog
import ProviderScene

@MainActor
final class AudioDownloadViewModel: SuperLog {
    static let emoji = "⬇️"
    private static let verbose = false
    private let playbackCapability: (any AudioDownloadPlaybackCapability)?
    private var currentScene: AppScene?
    private var generation = 0
    private var activeDownloadAssets: [URL] = []

    init(playbackCapability: (any AudioDownloadPlaybackCapability)?) {
        self.playbackCapability = playbackCapability
    }

    func handleSceneChange(_ scene: AppScene?) {
        if scene != .music { generation += 1 }
        currentScene = scene
        guard scene == .music else { return }
        handleAssetChanged(playbackCapability?.currentURL)
    }

    func handleAssetChanged(_ url: URL?) {
        guard currentScene == .music, let url, url.isNotDownloaded,
              !activeDownloadAssets.contains(where: { $0.isSameFileLocation(as: url) }) else { return }
        let requestGeneration = generation
        activeDownloadAssets.append(url)
        Task { @MainActor [weak self] in
            defer { self?.activeDownloadAssets.removeAll { $0.isSameFileLocation(as: url) } }
            guard let self, self.currentScene == .music,
                  self.generation == requestGeneration,
                  self.playbackCapability?.currentURL?.isSameFileLocation(as: url) == true else { return }
            do {
                try await url.ensureLocalAvailability()
                guard self.currentScene == .music, self.generation == requestGeneration,
                      self.playbackCapability?.currentURL?.isSameFileLocation(as: url) == true else { return }
                if Self.verbose { os_log("✅ 音频文件下载完成: %{public}@", url.lastPathComponent) }
            } catch {
                guard self.currentScene == .music, self.generation == requestGeneration else { return }
                os_log(.error, "音频文件下载失败: %{public}@", error.localizedDescription)
                alert_error(String(localized: "Download failed: \(error.localizedDescription)", bundle: .module))
            }
        }
    }
}

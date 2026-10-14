import Foundation
import MagicKit
import OSLog
import ProviderScene

@MainActor
final class AudioDownloadViewModel: SuperLog {
    static let emoji = "⬇️"
    private static let verbose = false
    /// 播放与提示能力（Capabilities 目录收窄），`weak` 持有。
    private weak var playback: (any AudioDownloadCapability)?
    private weak var toast: (any AudioDownloadToastCapability)?
    private var currentScene: AppScene?
    private var generation = 0
    private var activeDownloadAssets: [URL] = []

    init(
        playback: (any AudioDownloadCapability)?,
        toast: (any AudioDownloadToastCapability)? = nil
    ) {
        self.playback = playback
        self.toast = toast
    }

    func handleSceneChange(_ scene: AppScene?) {
        if scene != .music {
            generation = AudioDownloadRequestPolicy.generationAfterDeactivation(generation)
        }
        currentScene = scene
        guard scene == .music else { return }
        handleAssetChanged(playback?.currentURL)
    }

    func handleAssetChanged(_ url: URL?) {
        guard AudioDownloadRequestPolicy.shouldStartDownload(
            isSceneActive: currentScene == .music,
            asset: url,
            isNotDownloaded: url?.isNotDownloaded ?? false,
            activeDownloads: activeDownloadAssets
        ) else { return }
        let requestGeneration = generation
        activeDownloadAssets.append(url!)
        Task { @MainActor [weak self] in
            defer { self?.activeDownloadAssets.removeAll { $0.isSameFileLocation(as: url!) } }
            guard let self,
                  AudioDownloadRequestPolicy.shouldApplyDownloadResult(
                      requestedAsset: url,
                      currentAsset: self.playback?.currentURL,
                      isSceneActive: self.currentScene == .music,
                      currentGeneration: self.generation,
                      requestGeneration: requestGeneration
                  ) else { return }
            do {
                try await url!.ensureLocalAvailability()
                guard AudioDownloadRequestPolicy.shouldApplyDownloadResult(
                    requestedAsset: url,
                    currentAsset: self.playback?.currentURL,
                    isSceneActive: self.currentScene == .music,
                    currentGeneration: self.generation,
                    requestGeneration: requestGeneration
                ) else { return }
                if Self.verbose { os_log("✅ 音频文件下载完成: %{public}@", url!.lastPathComponent) }
            } catch {
                guard self.currentScene == .music, self.generation == requestGeneration else { return }
                os_log(.error, "音频文件下载失败: %{public}@", error.localizedDescription)
                toast?.error(String(localized: "Download failed: \(error.localizedDescription)", bundle: .module))
            }
        }
    }
}

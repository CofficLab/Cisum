import AVFoundation
import Combine
import Foundation
import CisumUIComponents
import LumiUI
import MagicKit
import OSLog
import SwiftUI

enum MagicPlayManDownloadRequestPolicy {
    static func shouldApplyResult(requestedAsset: URL, currentAsset: URL?) -> Bool {
        MagicPlayManAssetIdentity.representsSameAsset(requestedAsset, currentAsset)
    }

    static func shouldFinishDownload(requestedAsset: URL, currentAsset: URL?) -> Bool {
        MagicPlayManAssetIdentity.representsSameAsset(requestedAsset, currentAsset)
    }
}

enum MagicPlayManDownloadObserverPolicy {
    static func shouldUseObserver(requestedAsset: URL, observedAsset: URL?) -> Bool {
        MagicPlayManAssetIdentity.representsSameAsset(requestedAsset, observedAsset)
    }
}

enum MagicPlayManAssetIdentity {
    static func representsSameAsset(_ lhs: URL?, _ rhs: URL?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case let (.some(lhs), .some(rhs)):
            guard lhs.isFileURL, rhs.isFileURL else {
                return lhs == rhs
            }

            return canonicalIdentity(for: lhs) == canonicalIdentity(for: rhs)
        default:
            return false
        }
    }

    private static func canonicalIdentity(for url: URL) -> String {
        if isDanglingSymlink(url) {
            return url.standardizedFileURL.path
        }

        return url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private static func isDanglingSymlink(_ url: URL) -> Bool {
        guard (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true else {
            return false
        }

        return !FileManager.default.fileExists(atPath: url.path)
    }
}

extension Set where Element == URL {
    func containsSameAsset(as asset: URL) -> Bool {
        contains { MagicPlayManAssetIdentity.representsSameAsset($0, asset) }
    }

    mutating func removeSameAsset(as asset: URL) {
        self = filter { !MagicPlayManAssetIdentity.representsSameAsset($0, asset) }
    }
}

extension MagicPlayMan {
    /// 下载并缓存资源
    /// - Parameters:
    ///   - url: 要下载的资源 URL
    ///   - reason: 更新原因
    ///   - onFinished: 下载完成后的回调（主线程执行）
    @MainActor
    func downloadAndCache(_ url: URL, reason: String, onFinished: (() -> Void)? = nil) {
        guard cache != nil else {
            onFinished?()
            return
        }

        if url.isDownloaded {
            onFinished?()
            return
        }

        self.setState(.loading(.downloading(0)), reason: "\(reason).\(self.className).downloadAndCache")

        // 添加节流控制
        let progressSubject = CurrentValueSubject<Double, Never>(0)
        let progressObserver = url.onDownloading(verbose: self.verbose, caller: self.className + ".downloadAndCache") { progress in
            progressSubject.send(progress)
        }

        // 使用 Combine 的 throttle 操作符限制更新频率
        let progressUpdateObserver = progressSubject
            .throttle(for: .milliseconds(1000), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] progress in
                guard let self = self else { return }
                Task { @MainActor in
                    // 只有在加载状态时才更新下载进度，避免与播放状态冲突
                    if case .loading = self.state,
                       MagicPlayManDownloadRequestPolicy.shouldApplyResult(
                           requestedAsset: url,
                           currentAsset: self.currentURL
                       ) {
                        let progress = MagicPlayManPlaybackTimePolicy.normalizedUnitProgress(progress)
                        self.setState(.loading(.downloading(progress)), reason: "\(reason).\(self.className).downloadProgress")
                    }
                }
            }

        cancellables.insert(progressUpdateObserver)

        // 监听下载完成
        let finishObserver = url.onDownloadFinished(verbose: self.verbose, caller: self.className) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                guard MagicPlayManDownloadRequestPolicy.shouldFinishDownload(
                    requestedAsset: url,
                    currentAsset: self.currentURL
                ) else {
                    if self.verbose {
                        os_log("\(self.t)⚠️ URL changed during download completion, ignoring stale result for: \(url.title)")
                    }
                    self.cleanupDownloadObservers(for: url)
                    return
                }

                guard self.cleanupDownloadObservers(for: url) else {
                    return
                }

                // 下载完成后执行回调
                onFinished?()
            }
        }

        // 存储下载监听器引用
        self.setCurrentDownloadObservers((url, progressObserver, finishObserver))

        // 开始下载
        Task {
            do {
                try await url.ensureLocalAvailability()

                await MainActor.run {
                    guard MagicPlayManDownloadRequestPolicy.shouldFinishDownload(
                        requestedAsset: url,
                        currentAsset: self.currentURL
                    ) else {
                        if self.verbose {
                            os_log("\(self.t)⚠️ URL changed after ensuring local availability, ignoring stale result for: \(url.title)")
                        }
                        self.cleanupDownloadObservers(for: url)
                        return
                    }

                    guard self.cleanupDownloadObservers(for: url) else {
                        return
                    }

                    onFinished?()
                }
            } catch {
                await MainActor.run {
                    guard MagicPlayManDownloadRequestPolicy.shouldApplyResult(
                        requestedAsset: url,
                        currentAsset: self.currentURL
                    ) else {
                        if self.verbose {
                            os_log("\(self.t)⚠️ URL changed during download failure, ignoring error for: \(url.title)")
                        }
                        self.cleanupDownloadObservers(for: url)
                        return
                    }

                    // 下载失败时清理监听器
                    guard self.cleanupDownloadObservers(for: url) else {
                        return
                    }
                    self.setState(.failed(.networkError(error.localizedDescription)), reason: "\(reason).\(self.className).downloadAndCache")
                }
            }
        }
    }

    /// 清理下载监听器
    @MainActor
    @discardableResult
    private func cleanupDownloadObservers(for requestedAsset: URL) -> Bool {
        guard let observers = currentDownloadObservers,
              MagicPlayManDownloadObserverPolicy.shouldUseObserver(
                  requestedAsset: requestedAsset,
                  observedAsset: observers.asset
              ) else {
            return false
        }

        observers.progressObserver.cancel()
        observers.finishObserver.cancel()
        setCurrentDownloadObservers(nil)
        return true
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayMan.getPreviewView()
}

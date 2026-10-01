import AVFoundation
import SwiftUI
import Foundation
import CisumUIComponents
import LumiUI
import MagicKit

public extension MagicPlayMan {
    /// Returns the current playback error, if any.
    ///
    /// This property returns the error associated with the current failed playback state.
    /// If the player is not in a failed state, it returns `nil`.
    ///
    /// - Returns: The current `PlaybackError` or `nil` if there is no error.
    var currentError: PlaybackState.PlaybackError? {
        if case let .failed(error) = state {
            return error
        }
        return nil
    }

    /// 获取当前缓存目录
    var cacheDirectory: URL? {
        cache?.directory
    }

    /// 检查资源是否已缓存
    func isAssetCached(_ asset: MagicAsset) -> Bool {
        cache?.isCached(asset.url) ?? false
    }

    /// 获取缓存大小（字节）
    func cacheSize() throws -> UInt64 {
        try cache?.size() ?? 0
    }

    private func isSampleAsset(_ asset: MagicAsset) -> Bool {
        SupportedFormat.allSamples.contains { $0.asset.url == asset.url }
    }

    /// 剩余播放时间
    var remainingTime: TimeInterval {
        max(0, duration - currentTime)
    }

    /// 检查指定资源是否被喜欢
    func isAssetLiked(_ asset: MagicAsset) -> Bool {
        likedAssets.containsSameAsset(as: asset.url)
    }

    var player: AVPlayer { _player }
    var playing: Bool { self.state == .playing }
    var hasAsset: Bool { self.currentURL != nil }
    var currentAsset: URL? { currentURL }
    var asset: URL? { currentURL }
    var isLoading: Bool { if case .loading = self.state { return true } else { return false } }

    /// 当前资源是否被喜欢
    var isCurrentAssetLiked: Bool {
        guard let url = currentURL else { return false }
        return likedAssets.containsSameAsset(as: url)
    }

    /// 格式化后的当前播放时间，格式为 "mm:ss" 或 "hh:mm:ss"
    var currentTimeForDisplay: String {
        currentTime.displayFormat
    }

    /// 格式化后的总时长，格式为 "mm:ss" 或 "hh:mm:ss"
    var durationForDisplay: String {
        duration.displayFormat
    }

    /// 支持的媒体格式
    var supportedFormats: [SupportedFormat] {
        SupportedFormat.allFormats
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayMan.getPreviewView()
        .frame(height: 600)
}

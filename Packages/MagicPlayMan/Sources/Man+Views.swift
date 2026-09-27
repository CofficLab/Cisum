import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

/// MagicPlayMan 的视图相关功能扩展
/// 提供了一系列用于创建播放器界面组件的方法
public extension MagicPlayMan {
    /// 创建音频播放视图
    /// - Returns: 音频播放视图
    private func makeAudioView(url: URL) -> some View {
        AudioPlayerView(
            title: url.title,
            url: url,
            defaultArtwork: defaultArtwork,
            defaultArtworkBuilder: defaultArtworkBuilder
        )
    }

    /// 创建空状态视图
    /// - Returns: 空状态视图
    private func makeEmptyView() -> some View {
        AudioPlayerView(
            title: localization.noMediaSelected,
            artist: localization.selectMediaToPlay,
            defaultArtwork: defaultArtwork,
            defaultArtworkBuilder: defaultArtworkBuilder
        )
    }

    /// 获取预览视图
    /// - Parameter cacheDirectory: 自定义缓存目录，如果为 nil 则使用默认缓存目录
    /// - Returns: 预览视图实例
    static func getPreviewView(cacheDirectory: URL? = nil) -> some View {
        MagicPlayManPreviewView(cacheDirectory: cacheDirectory)
    }

    /// 创建播放状态视图
    /// - Returns: 返回一个显示播放器当前状态的视图，包括：
    /// - 播放/暂停状态
    /// - 当前播放资源的标题
    func makeStateView() -> some View {
        state.makeStateView(assetTitle: currentAsset?.title, localization: localization)
    }

    /// 创建媒体资源视图
    /// - Returns: 返回一个根据当前媒体资源类型自动适配的视图：
    /// - 当没有加载资源时，返回空视图
    /// - 当资源为视频时，返回视频播放视图
    /// - 当资源为音频时，返回音频播放视图，包括了音频的标题
    func makeMediaView() -> some View {
        return Group {
            if let currentAsset {
                if currentAsset.isAudio {
                    makeAudioView(url: currentAsset)
                } else {
                    makeVideoView()
                }
            } else {
                makeEmptyView()
            }
        }
    }

    /// 创建视频播放视图
    /// - Returns: 视频播放视图
    private func makeVideoView() -> some View {
        VideoPlayerView(player: player)
    }

    /// 创建播放进度条视图
    ///
    /// 这是一个自观察的进度条视图，会自动监听播放进度状态变化。
    /// 提供播放进度显示和拖动控制功能，支持实时进度更新和用户交互。
    ///
    /// - Returns: 自观察的播放进度条视图
    func makeProgressView() -> some View {
        MagicPlayProgressView(man: self)
    }

    /// 创建订阅者列表视图
    /// - Returns: 返回订阅者列表弹窗内容
    func makeSubscribersView() -> some View {
        SubscribersView(subscribers: events.subscribers)
            .frame(width: 300, height: 400)
            .padding()
    }

    /// 创建主要展示视图
    /// - Parameters:
    ///   - verbose: 是否启用详细日志
    ///   - avatarShape: Avatar 形状，如果为 nil 则使用默认形状
    /// - Returns: 返回一个根据当前媒体资源类型自动适配的主要展示视图：
    /// - 当资源为音频时，显示音频缩略图，不包括音频的标题和艺术家
    /// - 当资源为视频时，显示视频播放视图
    func makeHeroView(verbose: Bool = false, avatarShape: AvatarViewShape? = nil) -> some View {
        Group {
            if let currentAsset {
                if currentAsset.isAudio {
                    HeroView(url: currentAsset, verbose: verbose, avatarShape: avatarShape)
                } else {
                    makeVideoView()
                }
            } else {
                makeEmptyView()
            }
        }
    }

    func makeHeroView<Content: View>(
        verbose: Bool = false,
        avatarShape: AvatarViewShape? = nil,
        @ViewBuilder defaultView: () -> Content
    ) -> some View {
        Group {
            if let currentAsset {
                if currentAsset.isAudio {
                    HeroView(url: currentAsset, verbose: verbose, avatarShape: avatarShape)
                } else {
                    makeVideoView()
                }
            } else {
                defaultView()
            }
        }
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayMan.getPreviewView()
        .frame(height: 600)
}

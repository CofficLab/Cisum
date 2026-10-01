import CisumUIComponents
import LumiUI
import MagicKit
import OSLog
import SwiftUI

public extension MagicPlayMan {
    /// 自观察版本：播放/暂停按钮视图（推荐外部调用，零负担自动刷新）
    /// 
    /// 这是一个自观察的按钮视图，会自动监听播放状态变化并自动刷新。
    /// 无需外部订阅或手动刷新，推荐在 SwiftUI 视图中使用。
    /// 
    /// - Parameter size: 按钮尺寸，默认为 .regular
    /// - Returns: 自观察的播放/暂停按钮视图
    @MainActor
    @ViewBuilder
    func makePlayPauseButtonView(size: CGFloat = 28) -> some View {
        PlayPauseButtonView(man: self, size: size)
    }

    /// 获取播放/暂停按钮的动态 ID
    /// 用于在 SwiftUI View 中通过 .id() 修饰符响应状态变化
    var playPauseButtonId: String {
        if self.state.isLoading {
            return "play-pause-button-loading"
        } else if self.state == .playing {
            return "play-pause-button-playing"
        } else if self.state == .paused {
            return "play-pause-button-paused"
        } else if self.state == .stopped {
            return "play-pause-button-stopped"
        } else if case .failed = self.state {
            return "play-pause-button-failed"
        } else {
            return "play-pause-button-idle"
        }
    }

    /// 自观察版本：上一曲按钮视图
    /// 
    /// 这是一个自观察的按钮视图，会自动监听播放列表状态变化。
    /// 根据当前播放位置和播放列表状态智能管理按钮的可用性。
    /// 
    /// - Parameter size: 按钮尺寸，默认为 .regular
    /// - Returns: 自观察的上一曲按钮视图
    @MainActor
    @ViewBuilder
    func makePreviousButtonView(size: CGFloat = 28) -> some View {
        PreviousButtonView(man: self, size: size)
    }

    /// 自观察版本：下一曲按钮视图
    /// 
    /// 这是一个自观察的按钮视图，会自动监听播放列表状态变化。
    /// 根据当前播放位置和播放列表状态智能管理按钮的可用性。
    /// 
    /// - Parameter size: 按钮尺寸，默认为 .regular
    /// - Returns: 自观察的下一曲按钮视图
    @MainActor
    @ViewBuilder
    func makeNextButtonView(size: CGFloat = 28) -> some View {
        NextButtonView(man: self, size: size)
    }

    /// 自观察版本：快退按钮视图
    /// 
    /// 这是一个自观察的按钮视图，会自动监听播放状态变化。
    /// 提供快退功能，允许用户快速回退播放进度。
    /// 
    /// - Parameter size: 按钮尺寸，默认为 .regular
    /// - Returns: 自观察的快退按钮视图
    @MainActor
    @ViewBuilder
    func makeRewindButtonView(size: CGFloat = 28) -> some View {
        RewindButtonView(man: self, size: size)
    }

    /// 自观察版本：快进按钮视图
    /// 
    /// 这是一个自观察的按钮视图，会自动监听播放状态变化。
    /// 提供快进功能，允许用户快速前进播放进度。
    /// 
    /// - Parameter size: 按钮尺寸，默认为 .regular
    /// - Returns: 自观察的快进按钮视图
    @MainActor
    @ViewBuilder
    func makeForwardButtonView(size: CGFloat = 28) -> some View {
        ForwardButtonView(man: self, size: size)
    }

    /// 自观察版本：播放模式按钮视图
    /// 
    /// 这是一个自观察的按钮视图，会自动监听播放模式状态变化。
    /// 根据当前播放模式显示相应的图标和样式，支持循环、随机等播放模式切换。
    /// 
    /// - Parameter size: 按钮尺寸，默认为 .regular
    /// - Returns: 自观察的播放模式按钮视图
    @MainActor
    @ViewBuilder
    func makePlayModeButtonView(size: CGFloat = 28) -> some View {
        PlayModeButtonView(man: self, size: size)
    }

    /// 获取播放模式按钮的动态 ID
    /// 用于在 SwiftUI View 中通过 .id() 修饰符响应播放模式变化
    var playModeButtonId: String {
        return "play-mode-button-\(playMode.rawValue)"
    }

    /// 自观察版本：喜欢按钮视图
    /// 
    /// 这是一个自观察的按钮视图，会自动监听喜欢状态变化。
    /// 根据当前媒体资源的喜欢状态显示不同的图标和样式，支持喜欢/取消喜欢操作。
    /// 
    /// - Parameters:
    ///   - size: 按钮尺寸，默认为 .regular
    ///   - style: 按钮样式，默认为 nil（使用默认样式：喜欢时为 .primary，不喜欢时为 .secondary）
    ///   - shape: 按钮形状，默认为 .roundedSquare
    ///   - shapeVisibility: 形状显示时机，默认为 .always
    /// - Returns: 自观察的喜欢按钮视图
    @MainActor
    @ViewBuilder
    func makeLikeButtonView(size: CGFloat = 28) -> some View {
        LikeButtonView(man: self, size: size)
    }

    /// 获取喜欢按钮的动态 ID
    /// 用于在 SwiftUI View 中通过 .id() 修饰符响应喜欢状态变化
    var likeButtonId: String {
        if !hasAsset {
            return "like-button-no-asset"
        } else if isCurrentAssetLiked {
            return "like-button-liked"
        } else {
            return "like-button-not-liked"
        }
    }

    /// 自观察版本：订阅者按钮视图
    /// 
    /// 这是一个自观察的按钮视图，会自动监听订阅者状态变化。
    /// 提供订阅者列表查看功能，通过弹窗展示当前注册的事件订阅者信息。
    /// 
    /// - Parameter size: 按钮尺寸，默认为 .regular
    /// - Returns: 自观察的订阅者按钮视图
    @MainActor
    @ViewBuilder
    func makeSubscribersButtonView(size: CGFloat = 28) -> some View {
        SubscribersButtonView(man: self, size: size)
    }

    /// 创建媒体选择按钮
    /// - Returns: 用于选择媒体资源的按钮
    /// - Note: 按钮会显示当前选中的媒体名称，如果没有选中则显示默认文本
    func makeMediaPickerButton() -> some View {
        MediaPickerButton(
            man: self,
            selectedName: currentURL?.title,
            onSelect: { url in
                Task {
                    await self.play(url, reason: "makeMediaPickerButton")
                }
            }
        )
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayMan.getPreviewView()
        .frame(height: 600)
}

#Preview("Button Views") {
    let man = MagicPlayMan()

    VStack(spacing: 20) {
        // 媒体选择按钮
        man.makeMediaPickerButton()

        // 播放控制按钮组
        HStack(spacing: 16) {
            man.makePreviousButtonView()
            man.makeRewindButtonView()
            man.makePlayPauseButtonView()
            man.makeForwardButtonView()
            man.makeNextButtonView()
        }

        // 功能按钮组
        HStack(spacing: 16) {
            man.makePlayModeButtonView()
            man.makeLikeButtonView()
        }

        // 工具按钮组
        HStack(spacing: 16) {
            man.makeSubscribersButtonView()
        }

        // 不同尺寸的按钮示例
        VStack(spacing: 16) {
            Text(Localization.preview.differentSizes).font(.caption)
            HStack(spacing: 16) {
                man.makeLikeButtonView(size: 24)
                man.makeLikeButtonView(size: 28)
                man.makeLikeButtonView(size: 32)
            }
        }
    }
    .padding()
}

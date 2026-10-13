import Foundation
import ProviderPlayback
import SwiftUI

/// 播放封面的媒体渲染能力。
///
/// 内核 `PlaybackMediaProviding` 的两个成员全部被封面区消费，此处原样收窄。
///
/// 职责边界：具体封面视图的构造与状态文案本地化由播放引擎侧实现
/// （`MagicPlayMan` 持有播放器与本地化资源），本插件只负责「拿到并展示」，
/// 不重新实现渲染逻辑。
@MainActor
protocol HeroMediaCapability: AnyObject {
    /// 构造播放器的封面/媒体视图。
    func makeMediaView() -> AnyView

    /// 播放状态对应的本地化文案。
    func localizedStateText(for state: PlaybackStatus) -> String
}

/// 将内核 `PlaybackMediaProviding` 收窄为封面区的媒体渲染能力。
@MainActor
final class HeroMediaCapabilityAdapter: HeroMediaCapability {
    /// 持有内核 Provider 用 `weak`：Provider 可能已被 unregister，
    /// 此时能力退化为「空视图 + 原始描述」而非延长其生命周期。
    private weak var media: (any PlaybackMediaProviding)?

    init(media: (any PlaybackMediaProviding)?) {
        self.media = media
    }

    func makeMediaView() -> AnyView {
        media?.makeMediaView() ?? AnyView(EmptyView())
    }

    func localizedStateText(for state: PlaybackStatus) -> String {
        media?.localizedStateText(for: state) ?? String(describing: state)
    }
}
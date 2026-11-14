import Combine

/// 场景门：标识当前是否处于「音乐库」场景，供 root view 包装器观察。
///
/// 由 `AudioDBSceneObserver` 在场景切换时更新；`AudioDBPluginRootView`
/// 观察该状态，当场景不是音乐库时把自己的 root view 外壳下掉、直接透传
/// 内容区，切回音乐库时恢复外壳。
@MainActor
final class AudioDBSceneState: ObservableObject {
    @Published var isMusicScene: Bool

    init(isMusicScene: Bool) {
        self.isMusicScene = isMusicScene
    }
}

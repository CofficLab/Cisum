import CisumProviderStorage
import Foundation

/// 音乐库列表关心的存储状态：用于区分「首启尚未配置存储」与「仓库真的坏了」。
///
/// 两者都会让 `AudioLibraryCapability.isAvailable == false`，但用户可见后果完全不同：
///
/// - **首启引导中**：欢迎层已经解释了「请选择媒体存储位置」，此时再弹一个
///   通用仓库错误弹窗只会遮挡引导并吞掉点击；
/// - **真正的加载失败**：用户已经配好存储，仓库却打不开，必须告知。
@MainActor
protocol AudioLibraryStorageCapability: AnyObject {
    /// 是否已配置可用的存储位置。
    var hasUsableStorageLocation: Bool { get }
}

/// 将内核 `StorageProviding` 收窄为音乐库列表只需要的一位信息。
///
/// 持 `weak`：Provider 可能尚未注册或已被 unregister，此时退化为「尚未配置
/// 存储位置」，由 ViewModel 走静默分支，不会延长 Provider 生命周期。
@MainActor
final class AudioLibraryStorageCapabilityAdapter: AudioLibraryStorageCapability {
    private weak var storage: (any CisumProviderStorage.StorageProviding)?

    init(storage: (any CisumProviderStorage.StorageProviding)?) {
        self.storage = storage
    }

    var hasUsableStorageLocation: Bool {
        storage?.hasUsableStorageLocation ?? false
    }
}

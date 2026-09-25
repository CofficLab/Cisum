import CisumUIComponents
import Foundation
import ProviderAppState
import ProviderAudioLibrary
import ProviderAudioLike
import ProviderAudioNavigation
import ProviderCloud
import ProviderDevice
import ProviderPlayback
import ProviderStorage
import ProviderTheme
import ProviderToast

// MARK: - Service Accessors

extension CisumKernelContainer {
    /// 音频库服务 —— 提供 AudioDB 所需的抽象音频库能力。
    public var audioLibrary: (any AudioLibraryProviding)? {
        resolveProvider(AudioLibraryProviding.self)
    }

    /// 音频喜欢服务。
    public var audioLike: (any AudioLikeProviding)? {
        resolveProvider(AudioLikeProviding.self)
    }

    /// 音频曲目导航服务 —— 提供上一首、下一首以及首尾曲目查询。
    public var audioTrackNavigation: (any AudioTrackNavigationProviding)? {
        resolveProvider((any AudioTrackNavigationProviding).self)
    }

    /// 存储服务 —— 管理数据存储位置（iCloud / 本地 / 自定义）。
    public var storage: (any StorageProviding)? {
        resolveProvider(StorageProviding.self)
    }

    /// 播放服务 —— 控制音频/有声书播放状态。
    public var playback: (any PlaybackProviding)? {
        resolveProvider(PlaybackProviding.self)
    }

    /// 插件服务 —— 插件发现、注册、生命周期管理。
    public var plugin: (any PluginProviding)? {
        resolveProvider(PluginProviding.self)
    }

    /// 主题服务 —— 主题贡献收集、选择与同步。
    public var theme: (any ThemeProviding)? {
        resolveProvider(ThemeProviding.self)
    }

    /// 云同步服务 —— iCloud 状态监控。
    public var cloud: (any CloudProviding)? {
        resolveProvider(CloudProviding.self)
    }

    /// 应用状态服务 —— 应用级 UI 状态管理。
    public var appState: (any AppStateProviding)? {
        resolveProvider(AppStateProviding.self)
    }

    /// 设备数据服务 —— 设备信息访问。
    public var device: (any DeviceProviding)? {
        resolveProvider(DeviceProviding.self)
    }

    /// 全局消息、错误和加载状态提示服务。
    public var toast: (any ToastProviding)? {
        resolveProvider(ToastProviding.self)
    }
}

import CisumUIComponents
import Foundation
import ProviderAppState
import ProviderAudioLibrary
import ProviderAudioNavigation
import ProviderCloud
import ProviderDevice
import ProviderPlayback
import ProviderStorage
import ProviderTheme
import ProviderToast

// MARK: - Service Registration

extension CisumKernelContainer {
    /// 注册音频库服务。
    public func registerAudioLibrary(_ library: any AudioLibraryProviding) throws {
        try registerProvider(AudioLibraryProviding.self, library)
    }

    /// 注册音频曲目导航服务。
    public func registerAudioTrackNavigation(_ navigation: any AudioTrackNavigationProviding) throws {
        try registerProvider((any AudioTrackNavigationProviding).self, navigation)
    }

    /// 注册存储服务。
    public func registerStorage(_ storage: any StorageProviding) throws {
        try registerProvider(StorageProviding.self, storage)
    }

    /// 注册播放服务。
    public func registerPlayback(_ playback: any PlaybackProviding) throws {
        try registerProvider(PlaybackProviding.self, playback)
    }

    /// 注册插件管理服务。
    public func registerPluginService(_ plugin: any PluginProviding) throws {
        try registerProvider(PluginProviding.self, plugin)
    }

    /// 注册主题服务。
    public func registerThemeService(_ theme: any ThemeProviding) throws {
        try registerProvider(ThemeProviding.self, theme)
    }

    /// 注册云同步服务。
    public func registerCloudService(_ cloud: any CloudProviding) throws {
        try registerProvider(CloudProviding.self, cloud)
    }

    /// 注册应用状态服务。
    public func registerAppStateService(_ appState: any AppStateProviding) throws {
        try registerProvider(AppStateProviding.self, appState)
    }

    /// 注册设备数据服务。
    public func registerDeviceService(_ device: any DeviceProviding) throws {
        try registerProvider(DeviceProviding.self, device)
    }

    /// 注册全局消息/错误/加载提示服务。
    public func registerToastService(_ toast: any ToastProviding) throws {
        try registerProvider(ToastProviding.self, toast)
    }
}

import ProviderDocsView
import CisumProviderStorage
import ProviderToast
import KernelCore
import ProviderPlugin
import KitAppEvents
import CisumUIComponents
import LumiUI
import Foundation
import ProviderAudioLibrary
import SwiftUI
import MagicKit

@MainActor
public final class AudioPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: AudioPlugin.self)

    nonisolated static let verbose = false

    public static let shared = AudioPlugin()
    public let order = 1
    public let iconName: String = .cisumIconMusicNote
    public let metadata = PluginMetadata(
        id: String(describing: AudioPlugin.self),
        name: String(localized: String.LocalizationValue(AudioPluginInfo.titleKey), bundle: .module),
        description: String(localized: String.LocalizationValue(AudioPluginInfo.descriptionKey), bundle: .module),
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        self.kernel = kernel
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { AudioPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { AudioPluginManualView() })
        }
    }

    public static let maxAudioCount = AudioPluginInfo.maxAudioCount
    public static let supportedExtensions = AudioPluginInfo.supportedExtensions

    /// 当前构建生效的仓库子目录名（Release `audios` / DEBUG `audios_debug`）。
    public static let dbDirName = AudioPluginInfo.effectiveDBDirName

    nonisolated(unsafe) private var rootViewModel: AudioRootViewModel?

    /// 本插件消费的能力 Adapter。ViewModel 以 `weak` 持有，故入口必须显式
    /// 强持有，否则能力会随装配调用返回而释放。
    nonisolated(unsafe) private var storageCapability: AudioRootStorageCapabilityAdapter?
    nonisolated(unsafe) private var toastCapability: AudioRootToastCapabilityAdapter?
    nonisolated(unsafe) private var rootObserver: AudioStorageObserver?
    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?

    /// OnReady 阶段安装音频根视图的存储可用性观察者。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        guard kernel.resolveProvider((any StorageProviding).self) != nil else { return }
        installRootState(kernel: kernel)
    }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        // View 贡献可能在启动前被请求：保证返回稳定、长期存在的 ViewModel。
        let viewModel = rootViewModel ?? {
            let storage = AudioRootStorageCapabilityAdapter(
                storage: kernel?.resolveProvider((any StorageProviding).self)
            )
            let toast = AudioRootToastCapabilityAdapter(
                toast: kernel?.resolveProvider((any ToastProviding).self)
            )
            storageCapability = storage
            toastCapability = toast
            let viewModel = AudioRootViewModel(storage: storage, toast: toast)
            rootViewModel = viewModel
            return viewModel
        }()
        return AnyView(AudioRootView(viewModel: viewModel, content: content))
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        installRootState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        teardownRootState()
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        teardownRootState()
        self.kernel = nil
    }

    // MARK: - Root state assembly

    @MainActor
    private func installRootState(kernel: KernelCoreContainer) {
        guard rootViewModel == nil else { return }
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else { return }
        let storageCapability = AudioRootStorageCapabilityAdapter(storage: storage)
        let toastCapability = AudioRootToastCapabilityAdapter(
            toast: kernel.resolveProvider((any ToastProviding).self)
        )
        self.storageCapability = storageCapability
        self.toastCapability = toastCapability
        let viewModel = AudioRootViewModel(storage: storageCapability, toast: toastCapability)
        let observer = AudioStorageObserver(storage: storageCapability, viewModel: viewModel)
        rootViewModel = viewModel
        rootObserver = observer
    }

    @MainActor
    private func teardownRootState() {
        rootObserver?.cancel()
        rootObserver = nil
        rootViewModel = nil
    }

}

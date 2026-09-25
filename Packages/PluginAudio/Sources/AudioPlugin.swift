import ProviderDocsView
import ProviderStorage
import CisumKernelSupport
import CisumUIComponents
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
            let viewModel = AudioRootViewModel(
                hasStorageLocation: { @MainActor [weak self] in
                    self?.kernel?.resolveProvider((any StorageProviding).self)?.hasUsableStorageLocation ?? false
                }
            )
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
        let viewModel = AudioRootViewModel(
            hasStorageLocation: { storage.hasUsableStorageLocation }
        )
        let observer = AudioStorageObserver(provider: storage, viewModel: viewModel)
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
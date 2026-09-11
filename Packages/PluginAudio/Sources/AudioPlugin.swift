import KernelCore
import ProviderDocsView
import CisumUIComponents
import Foundation
import ProviderAudioLibrary
import ProviderStorage
import SwiftUI
import MagicKit

public actor AudioPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = AudioPlugin()
    public static let metadata = PluginMetadata(
        displayName: String(localized: String.LocalizationValue(AudioPluginInfo.titleKey), bundle: .module),
        description: String(localized: String.LocalizationValue(AudioPluginInfo.descriptionKey), bundle: .module),
        iconName: .cisumIconMusicNote,
        order: 1,
        category: .library,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        self.kernel = kernel
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioPluginManualView() })
        }
    }

    public static let maxAudioCount = AudioPluginInfo.maxAudioCount
    public static let supportedExtensions = AudioPluginInfo.supportedExtensions

    /// 当前构建生效的仓库子目录名（Release `audios` / DEBUG `audios_debug`）。
    public static let dbDirName = AudioPluginInfo.effectiveDBDirName

    nonisolated(unsafe) private var rootViewModel: AudioRootViewModel?
    nonisolated(unsafe) private var rootObserver: AudioStorageObserver?
    nonisolated(unsafe) private weak var kernel: CisumKernel?

    /// OnReady 阶段安装音频根视图的存储可用性观察者。
    @MainActor
    public func onReady(kernel: CisumKernel) async throws {
        self.kernel = kernel
        guard kernel.storage != nil else { return }
        installRootState(kernel: kernel)
    }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        // View 贡献可能在启动前被请求：保证返回稳定、长期存在的 ViewModel。
        let viewModel = rootViewModel ?? {
            let viewModel = AudioRootViewModel(
                hasStorageLocation: { @MainActor [weak self] in
                    self?.kernel?.storage?.hasUsableStorageLocation ?? false
                }
            )
            rootViewModel = viewModel
            return viewModel
        }()
        return AnyView(AudioRootView(viewModel: viewModel, content: content))
    }

    @MainActor
    public func onEnable(kernel: CisumKernel) async throws {
        self.kernel = kernel
        installRootState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: CisumKernel) async throws {
        teardownRootState()
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
        teardownRootState()
        self.kernel = nil
    }

    // MARK: - Root state assembly

    @MainActor
    private func installRootState(kernel: CisumKernel) {
        guard rootViewModel == nil else { return }
        guard let storage = kernel.storage else { return }
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

import ProviderAudioLibrary
import ProviderDocsView
import CisumUIComponents
import LumiUI
import KernelCore
import ProviderPlugin
import KitAppEvents
import ProviderToast
import SwiftUI
import MagicKit

#if os(macOS)
    @MainActor
public final class CopyPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: CopyPlugin.self)

    nonisolated static let verbose = false

        public static let shared = CopyPlugin()
        public let order = 0
    public let iconName = AudioCopyPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: CopyPlugin.self),
        name: String(localized: "Copy", bundle: .module),
        description: String(localized: String.LocalizationValue(AudioCopyPluginInfo.descriptionKey), bundle: .module),
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )

        nonisolated(unsafe) private weak var kernel: KernelCoreContainer?

    /// 复制能力 Adapter：由入口组装，注入 `AudioCopyService` 的静态持有
    /// （视同组装层所有权），内部惰性解析音频库 Provider。
    nonisolated(unsafe) private var libraryCapability: AudioCopyLibraryCapabilityAdapter?


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        self.kernel = kernel
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { CopyPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { CopyPluginManualView() })
        }
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let view = self.addStateView() { contrib.addStateView(ownerPluginID: id, view) }
        }
    }

        @MainActor
        public func addStateView() -> AnyView? {
            configureService()
            return AudioCopyService.getStateView()
        }

        @MainActor
        public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
            configureService()
            return AudioCopyService.getRootView { content() }
        }

        @MainActor
        private func configureService() {
            if libraryCapability == nil {
                libraryCapability = AudioCopyLibraryCapabilityAdapter { @MainActor [weak self] in
                    self?.kernel?.resolveProvider((any AudioLibraryProviding).self)
                }
            }
            AudioCopyService.configure(
                library: libraryCapability!,
                toast: AudioCopyToastCapabilityAdapter(
                    toast: self.kernel?.resolveProvider((any ToastProviding).self)
                )
            )
        }
    }
#endif

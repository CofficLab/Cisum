import ProviderAudioLibrary
import ProviderDocsView
import LumiUI
import KernelCore
import ProviderPlugin
import KitAppEvents
import ProviderStore
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

    /// 容量准入与购买呈现能力：入口强持有（Capabilities 规范第 5 条）。
    nonisolated(unsafe) private var capacityCapability: AudioCopyCapacityCapabilityAdapter?
    nonisolated(unsafe) private var purchaseCapability: AudioCopyPurchaseCapabilityAdapter?


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

        /// 容量准入能力（幂等）：内部惰性解析内核 Provider。
        ///
        /// 数据层插件的 boot 顺序不确定，复制视图贡献可能早于容量能力注册；
        /// 惰性解析让 Provider 稍后就绪时能力自动生效。
        @MainActor
        private func makeCapacityCapability() -> AudioCopyCapacityCapabilityAdapter {
            if let capacityCapability { return capacityCapability }
            let created = AudioCopyCapacityCapabilityAdapter { @MainActor [weak self] in
                self?.kernel?.resolveProvider((any AudioCapacityProviding).self)
            }
            capacityCapability = created
            return created
        }

        /// 购买面板呈现能力（幂等）：撞限引导用。
        @MainActor
        private func makePurchaseCapability() -> AudioCopyPurchaseCapabilityAdapter {
            if let purchaseCapability { return purchaseCapability }
            let created = AudioCopyPurchaseCapabilityAdapter { @MainActor [weak self] in
                self?.kernel?.resolveProvider((any StorePurchasePresenting).self)
            }
            purchaseCapability = created
            return created
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
                ),
                capacity: makeCapacityCapability(),
                purchase: makePurchaseCapability()
            )
        }
    }
#endif

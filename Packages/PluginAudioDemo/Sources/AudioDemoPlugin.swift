import ProviderAppState
import ProviderScene
import ProviderDocsView
import CisumKernelSupport
import CisumUIComponents
import SwiftUI
import MagicKit

@MainActor
public final class AudioDemoPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: AudioDemoPlugin.self)

    nonisolated static let verbose = false

    public static let shared = AudioDemoPlugin()
    public let order = 1
    public let iconName = AudioDemoPluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: AudioDemoPlugin.self),
        name: AudioDemoPluginInfo.title,
        description: AudioDemoPluginInfo.description,
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { AudioDemoPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { AudioDemoPluginManualView() })
        }
    }

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private let sceneBox = SceneBox()

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            contrib.addTabView { reason, demoMode in self.addTabView(reason: reason, demoMode: demoMode) }
        }
        self.kernel = kernel
        // 跨插件 Provider（Scene）在 onReady 中解析，
        // 不假设其他插件已完成 Provider 注册。
    }

    /// 所有 Provider 插件完成 onBoot 后再解析 Scene Provider。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        installScene(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        installScene(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        sceneBox.scene = nil
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        sceneBox.scene = nil
    }

    @MainActor
    public func addTabView(reason: String, demoMode: Bool = false) -> (view: AnyView, label: String)? {
        guard sceneBox.scene?.currentScene == .music else { return nil }
        guard demoMode else { return nil }

        let addButton = AnyView(
            AudioDemoAddButton(
                isImporting: Binding<Bool>(
                    get: { self.kernel?.resolveProvider((any AppStateProviding).self)?.isImporting ?? false },
                    set: { self.kernel?.resolveProvider((any AppStateProviding).self)?.setImporting($0) }
                )
            )
                .font(.title2)
                .labelStyle(.iconOnly)
        )

        return (
            AnyView(AudioListDemo(showAddButton: Self.isNotDesktop, addButton: addButton)),
            AudioDemoPluginInfo.tabLabel
        )
    }

    private static var isNotDesktop: Bool {
        #if os(macOS)
            false
        #else
            true
        #endif
    }

    // MARK: - State assembly

    @MainActor
    private func installScene(kernel: KernelCoreContainer) {
        guard let scene = kernel.resolveProvider((any SceneProviding).self) else { return }
        sceneBox.scene = scene
    }


    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}
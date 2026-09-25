import ProviderScene
import ProviderDocsView
import CisumKernelSupport
import CisumUIComponents
import SwiftUI
import MagicKit

@MainActor
public final class AudioScenePlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: AudioScenePlugin.self)

    nonisolated static let verbose = false

    public static let shared = AudioScenePlugin()
    public let order = AudioScenePluginInfo.order
    public let iconName = AudioScenePluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: AudioScenePlugin.self),
        name: AudioScenePluginInfo.title,
        description: AudioScenePluginInfo.description,
        version: "1.0.0",
        category: .core,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { AudioScenePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { AudioScenePluginManualView() })
        }
    }

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var setSceneAction: (@MainActor (AppScene) -> Void)?

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let view = self.addPosterView() { contrib.addPosterView(view) }
        }
        self.kernel = kernel
        // 跨插件 Provider（Scene）在 onReady 中解析，
        // 不假设其他插件已完成 Provider 注册。
    }

    /// 所有 Provider 插件完成 onBoot 后再解析 Scene Provider。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        installSceneAction(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        installSceneAction(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        setSceneAction = nil
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        setSceneAction = nil
    }

    @MainActor
    public func addPosterView() -> AnyView? {
        AnyView(AudioScenePluginPosterView(setCurrentScene: setSceneAction ?? { _ in }))
    }

    // MARK: - State assembly

    @MainActor
    private func installSceneAction(kernel: KernelCoreContainer) {
        guard let scene = kernel.resolveProvider((any SceneProviding).self) else { return }
        self.setSceneAction = { @MainActor sceneValue in
            scene.setCurrentScene(sceneValue)
        }
    }
}
import CisumKernel
import ProviderDocsView
import CisumUIComponents
import ProviderScene
import SwiftUI
import MagicKit

public actor AudioScenePlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = AudioScenePlugin()
    public static let metadata = PluginMetadata(
        displayName: AudioScenePluginInfo.title,
        description: AudioScenePluginInfo.description,
        iconName: AudioScenePluginInfo.iconName,
        order: AudioScenePluginInfo.order,
        category: .core,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioScenePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioScenePluginManualView() })
        }
    }

    nonisolated(unsafe) private weak var kernel: CisumKernel?
    nonisolated(unsafe) private var setSceneAction: (@MainActor (AppScene) -> Void)?

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        self.kernel = kernel
        // 跨插件 Provider（Scene）在 onReady 中解析，
        // 不假设其他插件已完成 Provider 注册。
    }

    /// 所有 Provider 插件完成 onBoot 后再解析 Scene Provider。
    @MainActor
    public func onReady(kernel: CisumKernel) async throws {
        installSceneAction(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: CisumKernel) async throws {
        self.kernel = kernel
        installSceneAction(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: CisumKernel) async throws {
        setSceneAction = nil
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
        setSceneAction = nil
    }

    @MainActor
    public func addPosterView() -> AnyView? {
        AnyView(AudioScenePluginPosterView(setCurrentScene: setSceneAction ?? { _ in }))
    }

    // MARK: - State assembly

    @MainActor
    private func installSceneAction(kernel: CisumKernel) {
        guard let scene = kernel.resolveProvider((any SceneProviding).self) else { return }
        self.setSceneAction = { @MainActor sceneValue in
            scene.setCurrentScene(sceneValue)
        }
    }
}

import ProviderScene
import ProviderDocsView
import CisumKernelSupport
import CisumUIComponents
import OSLog
import SwiftUI
import MagicKit

@MainActor
public final class BookScenePlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: BookScenePlugin.self)

    nonisolated static let verbose = false

    public static let shared = BookScenePlugin()
    public let order = BookScenePluginInfo.order
    public let iconName = BookScenePluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: BookScenePlugin.self),
        name: BookScenePluginInfo.title,
        description: BookScenePluginInfo.description,
        version: "1.0.0",
        category: .core,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if Self.verbose { os_log("\(Self.t)🔌 onRegister") }
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { BookScenePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { BookScenePluginManualView() })
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
        if Self.verbose { os_log("\(Self.t)🚀 onBoot") }
        // 跨插件 Provider（Scene）在 onReady 中解析，
        // 不假设其他插件已完成 Provider 注册。
    }

    /// 所有 Provider 插件完成 onBoot 后再解析 Scene Provider。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)🟢 onReady") }
        installSceneAction(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)✅ onEnable") }
        installSceneAction(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        if Self.verbose { os_log("\(Self.t)⏹️ onDisable") }
        setSceneAction = nil
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        if Self.verbose { os_log("\(Self.t)🛑 onShutdown") }
        setSceneAction = nil
    }

    @MainActor
    public func addPosterView() -> AnyView? {
        AnyView(BookScenePluginPosterView(setCurrentScene: setSceneAction ?? { _ in }))
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
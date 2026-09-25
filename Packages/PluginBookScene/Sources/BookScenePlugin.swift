import CisumKernel
import ProviderDocsView
import CisumUIComponents
import OSLog
import ProviderScene
import SwiftUI
import MagicKit

public actor BookScenePlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = BookScenePlugin()
    public static let metadata = PluginMetadata(
        displayName: BookScenePluginInfo.title,
        description: BookScenePluginInfo.description,
        iconName: BookScenePluginInfo.iconName,
        order: BookScenePluginInfo.order,
        category: .core,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if Self.verbose { os_log("\(Self.t)🔌 onRegister") }
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { BookScenePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { BookScenePluginManualView() })
        }
    }

    nonisolated(unsafe) private weak var kernel: CisumKernel?
    nonisolated(unsafe) private var setSceneAction: (@MainActor (AppScene) -> Void)?

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)🚀 onBoot") }
        // 跨插件 Provider（Scene）在 onReady 中解析，
        // 不假设其他插件已完成 Provider 注册。
    }

    /// 所有 Provider 插件完成 onBoot 后再解析 Scene Provider。
    @MainActor
    public func onReady(kernel: CisumKernel) async throws {
        if Self.verbose { os_log("\(Self.t)🟢 onReady") }
        installSceneAction(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: CisumKernel) async throws {
        self.kernel = kernel
        if Self.verbose { os_log("\(Self.t)✅ onEnable") }
        installSceneAction(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: CisumKernel) async throws {
        if Self.verbose { os_log("\(Self.t)⏹️ onDisable") }
        setSceneAction = nil
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
        if Self.verbose { os_log("\(Self.t)🛑 onShutdown") }
        setSceneAction = nil
    }

    @MainActor
    public func addPosterView() -> AnyView? {
        AnyView(BookScenePluginPosterView(setCurrentScene: setSceneAction ?? { _ in }))
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

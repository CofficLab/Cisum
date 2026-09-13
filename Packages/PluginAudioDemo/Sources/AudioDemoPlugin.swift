import KernelCore
import ProviderDocsView
import CisumUIComponents
import ProviderScene
import SwiftUI
import MagicKit

public actor AudioDemoPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = AudioDemoPlugin()
    public static let metadata = PluginMetadata(
        displayName: AudioDemoPluginInfo.title,
        description: AudioDemoPluginInfo.description,
        iconName: AudioDemoPluginInfo.iconName,
        order: 1,
        category: .tool,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioDemoPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { AudioDemoPluginManualView() })
        }
    }

    nonisolated(unsafe) private weak var kernel: CisumKernel?
    nonisolated(unsafe) private let sceneBox = SceneBox()

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        self.kernel = kernel
        // 跨插件 Provider（Scene）在 onReady 中解析，
        // 不假设其他插件已完成 Provider 注册。
    }

    /// 所有 Provider 插件完成 onBoot 后再解析 Scene Provider。
    @MainActor
    public func onReady(kernel: CisumKernel) async throws {
        installScene(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: CisumKernel) async throws {
        self.kernel = kernel
        installScene(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: CisumKernel) async throws {
        sceneBox.scene = nil
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
        sceneBox.scene = nil
    }

    @MainActor
    public func addTabView(reason: String, demoMode: Bool = false) -> (view: AnyView, label: String)? {
        guard sceneBox.scene?.currentScene == .music else { return nil }
        guard demoMode else { return nil }

        let addButton = AnyView(
            AudioDemoAddButton(
                isImporting: Binding<Bool>(
                    get: { self.kernel?.appState?.isImporting ?? false },
                    set: { self.kernel?.appState?.setImporting($0) }
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
    private func installScene(kernel: CisumKernel) {
        guard let scene = kernel.resolveProvider((any SceneProviding).self) else { return }
        sceneBox.scene = scene
    }


    private final class SceneBox {
        weak var scene: (any SceneProviding)?
    }
}

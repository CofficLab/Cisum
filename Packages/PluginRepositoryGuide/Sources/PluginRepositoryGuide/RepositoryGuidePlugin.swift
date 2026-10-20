import KernelCore
import LumiUI
import MagicKit
import ProviderAudioLibrary
import ProviderControlView
import ProviderDocsView
import ProviderPlugin
import ProviderScene
import SwiftUI

/// 空仓库引导插件：仓库为空时，向播放控制区注入引导视图（`setGuideSlot`）。
///
/// 引导只负责「怎么开始」：品牌区 + 拖放框。它不知道自己服务的是哪个仓库域，
/// 仓库是否为空由观察者按业务事件判定——插件层只提供引导位与呈现内容。
@MainActor
public final class RepositoryGuidePlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: RepositoryGuidePlugin.self)

    nonisolated static let verbose = false

    public static let shared = RepositoryGuidePlugin()
    public let order = 20
    public let iconName = "sparkles"
    public let metadata = PluginMetadata(
        id: String(describing: RepositoryGuidePlugin.self),
        name: String(localized: String.LocalizationValue("Repository Guide"), bundle: .module),
        description: String(localized: String.LocalizationValue("Shows a first-run guide when the repository is empty."), bundle: .module),
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?

    /// 本插件消费的能力 Adapter。观察器以 `weak` 持有，故入口必须显式强持有，
    /// 否则能力会随装配调用返回而释放。
    nonisolated(unsafe) private var libraryCapability: GuideLibraryCapabilityAdapter?
    nonisolated(unsafe) private var sceneCapability: GuideSceneCapabilityAdapter?

    /// 引导插槽（顶部引导视图），注入播放控制区。
    ///
    /// 插槽实例在插件生命周期内保持同一份：控制区在装配时按值捕获插槽，
    /// 换实例会让已渲染的控制区失去引导。
    nonisolated(unsafe) private var guideSlot: ControlGuideSlot?

    /// 引导激活态观察者：仓库变空时点亮引导，变非空时熄灭。
    nonisolated(unsafe) private var guideObserver: RepositoryGuideObserver?

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { RepositoryGuidePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { RepositoryGuidePluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
    }

    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        installState(kernel: kernel)
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        teardownState()
        self.kernel = nil
    }

    /// 装配引导：插槽 + 视图 + 观察者，并注入播放控制区。
    @MainActor
    private func installState(kernel: KernelCoreContainer?) {
        guard guideSlot == nil, let kernel else { return }

        let library = GuideLibraryCapabilityAdapter { @MainActor [weak self] in
            self?.kernel?.resolveProvider((any AudioLibraryProviding).self)
        }
        let scene = GuideSceneCapabilityAdapter(
            scene: kernel.resolveProvider((any SceneProviding).self)
        )
        libraryCapability = library
        sceneCapability = scene

        let slot = ControlGuideSlot(
            guideView: AnyView(RepositoryGuideView())
        )
        guideSlot = slot
        kernel.resolveProvider((any ControlViewProviding).self)?.setGuideSlot(slot)

        guideObserver = RepositoryGuideObserver(
            slot: slot,
            library: library,
            scene: scene
        )
    }

    /// 拆除引导：熄灭插槽、取消订阅、释放能力。
    @MainActor
    private func teardownState() {
        guideObserver?.cancel()
        guideObserver = nil
        guideSlot?.isActive = false
        guideSlot = nil
        libraryCapability = nil
        sceneCapability = nil
    }
}

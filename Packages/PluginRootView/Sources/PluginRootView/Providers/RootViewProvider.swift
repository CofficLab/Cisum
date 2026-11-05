import KernelCore
import ProviderRootView
import SwiftUI

/// Uses LumiProviders' shared root-view state with Cisum's own player layout.
@MainActor
public final class RootViewProvider: DefaultRootViewProviding {
    private weak var kernel: KernelCoreContainer?

    public init(kernel: KernelCoreContainer) {
        self.kernel = kernel
        super.init()
    }

    public override func makeRootView() -> AnyView {
        guard let kernel else { return AnyView(EmptyView()) }
        return AnyView(RootOverlayHostView(provider: self, kernel: kernel))
    }

    /// 内容区显隐：区域隐藏与「内容区是否隐藏」必须保持同步。
    ///
    /// 基类的 `setContentViewHidden(_:)` 走 `setRegionHidden(_:for:)`，只写
    /// `hiddenRegions` 这个 `Set`；而 `isContentViewHidden` 是**另一个**
    /// `@Published Bool`，基类从不更新它。后果：
    ///
    /// - `isContentViewVisible`（= `!isContentViewHidden`）恒为 `true`，
    ///   「更多」按钮按它取反算出的目标态永远是「隐藏」，点了没反应；
    /// - `RootLayoutView.onChange(of: provider.isContentViewHidden)` 永不触发，
    ///   内容区显隐不会跟着变。
    ///
    /// 这里把两者同步，并让区域状态成为唯一真源。
    public override func setContentViewHidden(_ hidden: Bool) {
        super.setContentViewHidden(hidden)
        if isContentViewHidden != hidden {
            isContentViewHidden = hidden
        }
    }
}

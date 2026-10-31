import Foundation
import ProviderStore
import SwiftUI

/// 购买面板的呈现状态机。
///
/// 商店设置页里的购买面板是「挂在设置页上的 sheet」，撞限引导需要的是
/// 「从任意位置弹出来的面板」。两者是同一份内容，但承载方式不同：
/// - 设置页：sheet 挂在 `StoreSetting` 上，跟着设置页的打开/关闭走；
/// - 全局引导：overlay 挂在根视图上，由本状态机驱动。
///
/// 状态机只持一个 `isPresented` 布尔量，够用且不会出状态组合问题。
@MainActor
final class StorePurchasePresentation: ObservableObject {
    /// 购买面板是否应呈现。
    @Published private(set) var isPresented = false

    /// 呈现购买面板（幂等）。
    func present() {
        isPresented = true
    }

    /// 关闭购买面板。
    func dismiss() {
        isPresented = false
    }
}

/// `StorePurchasePresenting` 的实现：把「请商店呈现购买面板」接到全局 overlay。
///
/// 呈现路径：根视图 overlay（`RootOverlayItem`）→ `StorePurchaseOverlay`。
/// overlay 始终挂在根上，但面板内容由 `isPresented` 控制显隐，因此「未弹出」
/// 时不占位、不拦截交互。
@MainActor
public final class StorePurchasePresentingProvider: StorePurchasePresenting {
    private let presentation: StorePurchasePresentation

    init(presentation: StorePurchasePresentation) {
        self.presentation = presentation
    }

    public func presentPurchase() {
        presentation.present()
    }
}

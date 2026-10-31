import LumiUI
import SwiftUI

/// 挂在根视图上的购买面板覆盖层。
///
/// 始终挂在根视图，但只有 `isPresented` 为真时才渲染面板内容——未触发的
/// 时候不占位、不拦截底层交互。
///
/// 面板内容复用设置页的 `PurchaseView`（同一份商品列表与版本对比），
/// 避免两处各维护一份购买界面。
///
/// ## 内容层的位置
///
/// 底层内容（`content`，即整个应用根视图）必须是**主体层**，
/// 购买面板作为它的 `overlay` 叠加上去。
///
/// 不能写成 `StorePurchaseOverlay(...).overlay(content)`——那样内容变成了
/// 「空视图的覆盖层」：基础层未呈现任何东西时，SwiftUI 不会给覆盖层分配
/// 尺寸，整棵根视图（含音乐库、工具栏）都渲染不出来，主窗口只剩背景。
struct StorePurchaseOverlay<Content: View>: View {
    @ObservedObject var presentation: StorePurchasePresentation
    private let content: Content

    init(presentation: StorePurchasePresentation, @ViewBuilder content: () -> Content) {
        self.presentation = presentation
        self.content = content()
    }

    var body: some View {
        content
            .overlay {
                if presentation.isPresented {
                    ZStack {
                        // 遮罩：点击关闭，给出「这是临时弹层」的明确视觉边界。
                        Color.black.opacity(0.28)
                            .ignoresSafeArea()
                            .onTapGesture {
                                presentation.dismiss()
                            }

                        PurchaseView(onClose: { presentation.dismiss() })
                            .frame(maxWidth: 520, maxHeight: 640)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: presentation.isPresented)
    }
}

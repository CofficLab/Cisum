import LumiUI
import SwiftUI

/// 挂在根视图上的购买面板覆盖层。
///
/// 始终挂在根视图，但只有 `isPresented` 为真时才渲染面板内容——未触发的
/// 时候不占位、不拦截底层交互。
///
/// 面板内容复用设置页的 `PurchaseView`（同一份商品列表与版本对比），
/// 避免两处各维护一份购买界面。
struct StorePurchaseOverlay: View {
    @ObservedObject var presentation: StorePurchasePresentation

    var body: some View {
        Group {
            if presentation.isPresented {
                ZStack {
                    // 遮罩：点击关闭，给出「这是临时弹层」的明确视觉边界。
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .onTapGesture {
                            presentation.dismiss()
                        }

                    PurchaseView()
                        .frame(maxWidth: 520, maxHeight: 640)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: presentation.isPresented)
    }
}

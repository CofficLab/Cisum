import MagicKit
import SwiftUI

// MARK: - Sheet Container

/// Sheet 容器
///
/// 用于包装 Sheet 视图内容，提供统一的布局和交互样式
/// 在 macOS 平台自动显示关闭按钮，iOS 平台不显示
///
/// ## 使用示例
/// ```swift
/// SheetContainer {
///     VStack {
///         Text("标题")
///         Text("内容")
///     }
/// }
/// ```
struct SheetContainer<Content: View>: View {
    @Environment(\.dismiss) private var dismiss

    /// 内容视图
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 40) {
            // 关闭按钮区域（仅 macOS 显示）
            HStack {
                Spacer()
                closeButton
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
            .if(Config.isDesktop)

            // iOS 上需要一些空白，方便用户下拉关闭
            Spacer(minLength: 20)
                .if(Config.isiOS)

            // 用户内容
            content
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
        }
        .background(Config.rootBackground)
        .infinite()
        .ignoresSafeArea()
    }

    // MARK: - 子视图组件

    /// 关闭按钮 - 现代化圆形设计
    private var closeButton: some View {
        @State var hovered = false

        return
            Image.close
                .font(.system(size: 20, weight: .medium))
                .frame(width: 32, height: 32)
                .foregroundStyle(.secondary)
                .background(.regularMaterial, in: Circle())
                .shadowSm()
                .inButtonWithAction {
                    dismiss()
                }
                .hoverScale(105)
        #if os(iOS)
            .scaleEffect(hovered ? 0.95 : 1.0)
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.1)) {
                    hovered = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation { hovered = false }
                }
            }
        #endif
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

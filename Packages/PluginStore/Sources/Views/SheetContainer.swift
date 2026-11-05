import LumiUI
import SwiftUI

struct SheetContainer<Content: View>: View {
    nonisolated static var closeButtonLabel: String {
        String(localized: "Close", bundle: .module)
    }

    @Environment(\.dismiss) private var dismiss
    @LumiTheme private var appTheme

    /// 关闭动作。
    ///
    /// 默认走 SwiftUI 的 `dismiss()`——适用于**真正的 sheet**。
    /// 但购买面板在全局引导里是挂在根视图上的 **overlay**（不是 sheet），
    /// 此时 `dismiss()` 没有任何东西可关：面板纹丝不动，用户点了关闭
    /// 却像坏了。因此 overlay 路径必须显式传入自己的关闭动作。
    var onClose: (() -> Void)?

    @ViewBuilder var content: Content

    init(onClose: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.onClose = onClose
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 40) {
#if os(macOS)
            HStack {
                Spacer()
                closeButton
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
#else
            Spacer(minLength: 20)
#endif

            content
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
        }
        .background(appTheme.background)
        .appFillAvailableSpace()
        .ignoresSafeArea()
    }

    private var closeButton: some View {
        Image.appClose
            .font(.system(size: 20, weight: .medium))
            .frame(width: 32, height: 32)
            .foregroundStyle(.secondary)
            .background(.regularMaterial, in: Circle())
            .shadowSm()
            .appPlainButton {
                if let onClose {
                    onClose()
                } else {
                    dismiss()
                }
            }
            .accessibilityLabel(Self.closeButtonLabel)
            .help(Self.closeButtonLabel)
            .appHoverScale(1.05)
    }
}

import CisumUIComponents
import LumiUI
import SwiftUI

struct SheetContainer<Content: View>: View {
    nonisolated static var closeButtonLabel: String {
        String(localized: "Close", bundle: .module)
    }

    @Environment(\.dismiss) private var dismiss
    @LumiTheme private var appTheme

    @ViewBuilder var content: Content

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
        .cisumInfinite()
        .ignoresSafeArea()
    }

    private var closeButton: some View {
        Image.cisumClose
            .font(.system(size: 20, weight: .medium))
            .frame(width: 32, height: 32)
            .foregroundStyle(.secondary)
            .background(.regularMaterial, in: Circle())
            .cisumShadowSm()
            .cisumButton {
                dismiss()
            }
            .accessibilityLabel(Self.closeButtonLabel)
            .help(Self.closeButtonLabel)
            .cisumHoverScale(105)
    }
}

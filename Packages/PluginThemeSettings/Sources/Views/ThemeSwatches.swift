import CisumUIComponents
import LumiUI
import SwiftUI

/// 主题色板小圆点（预览 chrome 主题的 accent / atmosphere 色）。
struct ThemeSwatches: View {
    let theme: any LumiAppChromeTheme

    var body: some View {
        let accent = theme.accentColors()
        let atmosphere = theme.atmosphereColors()

        HStack(spacing: 4) {
            swatch(atmosphere.deep)
            swatch(atmosphere.light)
            swatch(accent.primary)
            swatch(accent.secondary)
        }
        .accessibilityHidden(true)
    }

    private func swatch(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
    }
}

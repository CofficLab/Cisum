import MagicKit
import SwiftUI

extension View {
    func asPosterTitle() -> some View {
        self.bold()
            .font(.system(size: 100, design: .rounded))
            .padding(.bottom, 40)
            .shadowSm()
    }

    func asPosterTitleForIPhone() -> some View {
        self.bold()
            .font(.system(size: 150, design: .rounded))
            .padding(.bottom, 40)
            .shadowSm()
    }

    func asPosterSubTitle() -> some View {
        self.font(.system(size: 50, design: .rounded))
            .foregroundStyle(.secondary)
            .shadowSm()
    }
    
    func asPosterSubTitleForIPhone() -> some View {
        self.font(.system(size: 40, design: .rounded))
            .foregroundStyle(.secondary)
            .shadowSm()
    }
}

// MARK: - Preview

#Preview("App Store Hero") {
    AppStoreHero()
        .inMagicContainer(.macBook13, scale: 0.5)
}

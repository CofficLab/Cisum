import MagicKit
import OSLog
import SwiftUI

struct WelcomeView: View, SuperLog {
    nonisolated static let emoji = "🎉"
    static let verbose = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 8)

                Text("美好即将开始")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)

                Text("准备好探索你的音乐世界")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            StorageView()
                .background(.regularMaterial)
                .roundedMedium()
                .shadowSm()

            Spacer()
        }
        .padding(24)
    }
}

#Preview("WelcomeView") {
    WelcomeView()
        .inRootView()
        .withDebugBar()
        .preferredColorScheme(.light)
}

#Preview("WelcomeView - Dark") {
    WelcomeView()
        .inRootView()
        .withDebugBar()
        .preferredColorScheme(.dark)
}

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

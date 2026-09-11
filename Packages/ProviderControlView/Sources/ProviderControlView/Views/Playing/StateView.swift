import CisumUIComponents
import SwiftUI

/// 播放状态提示。
struct StateView: View {
    @Environment(\.demoMode) private var isDemoMode
    @LumiTheme private var appTheme
    let stateViews: @MainActor () -> [AnyView]
    let stateMessage: @MainActor () -> String

    var body: some View {
        let message = stateMessage()
        let contributedViews = stateViews()
        if !isDemoMode, !message.isEmpty || !contributedViews.isEmpty {
            VStack(spacing: 10) {
                if !message.isEmpty {
                    infoView(message)
                }

                ForEach(Array(contributedViews.enumerated()), id: \.offset) { _, view in
                    view
                }
            }
        }
    }

    private func infoView(_ text: String) -> some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(appTheme.textPrimary)
            Text(text)
                .foregroundStyle(appTheme.textPrimary)
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(appTheme.elevatedSurface, in: Capsule())
    }
}

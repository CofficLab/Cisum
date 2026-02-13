import MagicKit
import SwiftUI
import MagicAlert

/// 音频海报视图，展示示例曲目列表。
struct AudioPoster: View {
    @EnvironmentObject private var pluginProvider: PluginProvider
    @Environment(\.posterDismissAction) private var dismissAction

    var books: [String] = [
        "挪威的森林",
        "歌唱祖国",
        "让我们荡起双桨",
        "遇见",
        "青花瓷",
        "伤心太平洋",
        "一千个伤心的理由",
    ]

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                ForEach(books, id: \.self) { item in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(iconGradient)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image.musicNote
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(.blue.opacity(0.8))
                            )
                        Text(item)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)

                    if item != books.last {
                        Divider()
                            .padding(.leading, 58)
                    }
                }
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.12),
                                Color.cyan.opacity(0.12),
                                Color.teal.opacity(0.10),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            )

            Spacer()

            Button(action: {
                Task { @MainActor in
                    do {
                        try pluginProvider.setCurrentScene(String(localized: "Music Library"))
                        dismissAction()
                    } catch {
                        alert_error(error)
                    }
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle")
                    Text(String(localized: "Enter Music Repository"))
                }
                .frame(width: 130, height: 40)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
    }

    private var iconGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.18),
                Color.cyan.opacity(0.22),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview("Poster") {
    AudioPoster()
        .frame(width: 600)
        .frame(height: 600)
}

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

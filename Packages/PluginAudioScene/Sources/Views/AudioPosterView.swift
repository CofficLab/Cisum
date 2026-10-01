import CisumUIComponents
import LumiUI
import SwiftUI

public typealias AudioSceneEnterAction = @MainActor () -> Void
public typealias AudioSceneDismissAction = @MainActor () -> Void

/// 音频海报视图，展示示例曲目列表。
public struct AudioPosterView: View {
    @LumiTheme private var appTheme
    private let enterScene: AudioSceneEnterAction
    private let dismissPoster: AudioSceneDismissAction

    private let tracks: [String] = [
        "挪威的森林",
        "歌唱祖国",
        "让我们荡起双桨",
        "遇见",
        "青花瓷",
        "伤心太平洋",
        "一千个伤心的理由",
    ]

    public init(
        enterScene: @escaping AudioSceneEnterAction,
        dismissPoster: @escaping AudioSceneDismissAction = {}
    ) {
        self.enterScene = enterScene
        self.dismissPoster = dismissPoster
    }

    public var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                ForEach(tracks, id: \.self) { item in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(iconGradient)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image.cisumMusicNote
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(appTheme.primary.opacity(0.8))
                            )
                        Text(item)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)

                    if item != tracks.last {
                        Divider()
                            .padding(.leading, 58)
                    }
                }
            }
            .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(appTheme.primary.opacity(0.12))
                        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                )

            Spacer()

            Button(action: {
                Task { @MainActor in
                    enterScene()
                    dismissPoster()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle")
                    Text("Enter Music Repository", bundle: .module)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(minWidth: 210, maxWidth: 280, minHeight: 44)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
    }

    private var iconGradient: LinearGradient {
        LinearGradient(
            colors: [
                appTheme.primary.opacity(0.18),
                appTheme.primarySecondary.opacity(0.22),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

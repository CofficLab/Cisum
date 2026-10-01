import CisumUIComponents
import LumiUI
import SwiftUI

public typealias BookSceneEnterAction = @MainActor () -> Void
public typealias BookSceneDismissAction = @MainActor () -> Void

/// 有声书海报视图，展示示例书目。
public struct BookPosterView: View {
    @LumiTheme private var appTheme
    private let enterScene: BookSceneEnterAction
    private let dismissPoster: BookSceneDismissAction

    var books: [String] = [
        "巴黎圣母院",
        "海底两万里",
        "三国演义",
        "西游记",
        "红楼梦",
        "水浒传",
        "三体",
        "百年孤独",
        "追风筝的人",
        "白夜行",
        "挪威的森林",
    ]

    public init(
        enterScene: @escaping BookSceneEnterAction,
        dismissPoster: @escaping BookSceneDismissAction = {}
    ) {
        self.enterScene = enterScene
        self.dismissPoster = dismissPoster
    }

    public var body: some View {
        VStack(spacing: 16) {
            hStackView

            Spacer()

            Button(action: {
                Task { @MainActor in
                    enterScene()
                    dismissPoster()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: .cisumIconArrowUpCircle)
                    Text("Enter Audiobook Library", bundle: .module)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(minWidth: 210, maxWidth: 280)
                .padding(.vertical, 10)
                .background(appTheme.primary, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
            }
            .frame(minHeight: 44)
        }
        .padding()
    }

    var hStackView: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(books.enumerated()), id: \.offset) { index, title in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(spineGradient(index: index))
                            .frame(width: 60, height: 200)
                            .shadow(radius: 2, y: 1)
                            .overlay(
                                VStack {
                                    Spacer()
                                    VStack(spacing: 4) {
                                        ForEach(Array(title.prefix(10)), id: \.self) { ch in
                                            Text(String(ch))
                                                .font(.headline.weight(.semibold))
                                                .foregroundStyle(.white)
                                                .minimumScaleFactor(0.6)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                }
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // 书架底座
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.brown.opacity(0.55), Color.brown.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 12)
                .shadow(radius: 2, y: 1)
        }
    }

    var gridView: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 120), spacing: 15),
        ], pinnedViews: [.sectionHeaders]) {
            ForEach(books, id: \.self) { item in
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        Text(item)
                        Spacer()
                    }
                    Spacer()
                }
                .background(appTheme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)))
                .frame(width: 130)
                .frame(height: 180)
            }
        }
        .padding()
    }

    private func spineGradient(index: Int) -> LinearGradient {
        let palette: [[Color]] = [
            [.indigo, .purple],
            [.mint, .teal],
            [.orange, .red],
            [.blue, .cyan],
            [.pink, .purple],
            [.green, .teal],
        ]
        let colors = palette[index % palette.count]
        return LinearGradient(colors: colors.map { $0.opacity(0.8) },
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
    }
}

import SwiftUI
import MagicKit

/// 有声书海报视图，展示示例书目。
struct BookPoster: View {
    @EnvironmentObject private var pluginProvider: PluginProvider
    @EnvironmentObject private var m: MagicMessageProvider
    @Environment(\.posterDismissAction) private var dismissAction

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

    var body: some View {
        VStack(spacing: 16) {
            hStackView

            Spacer()

            Button(action: {
                Task { @MainActor in
                    do {
                        try pluginProvider.setCurrentScene("有声书")
                        dismissAction()
                    } catch {
                        m.error(error)
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: .iconArrowUpCircle)
                    Text("进入有声书仓库")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.blue, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
            }
            .frame(width: 130)
            .frame(height: 40)
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
                .background(MagicBackground.deepOceanCurrent)
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

#Preview("Poster") {
    BookPoster()
        .frame(width: 600)
        .frame(height: 600)
}

#if os(macOS)
#Preview("App - Large") {
    ContentView()
    .inRootView()
        .frame(width: 600, height: 1000)
}

#Preview("App - Small") {
    ContentView()
    .inRootView()
        .frame(width: 600, height: 600)
}
#endif

#if os(iOS)
#Preview("iPhone") {
    ContentView()
    .inRootView()
}
#endif

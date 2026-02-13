import SwiftUI

struct BookLikeSettingsView: View, SuperLog {
    nonisolated static var emoji: String { "❤️" }
    private static var verbose: Bool { false }

    @State private var likedBooks: [String] = []
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("喜欢的书籍")
                .font(.headline)

            if isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if likedBooks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("还没有喜欢的书籍")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(likedBooks, id: \.self) { bookName in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(bookName)
                                .font(.body)
                        }
                        Spacer()
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .padding()
        .frame(minWidth: 300, minHeight: 400)
        .onAppear {
            loadLikedBooks()
        }
    }

    private func loadLikedBooks() {
        // 这里可以实现加载喜欢的书籍列表
        // 暂时使用示例数据
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.likedBooks = [
                "示例书籍 1",
                "示例书籍 2",
                "示例书籍 3"
            ]
            self.isLoading = false
        }
    }
}

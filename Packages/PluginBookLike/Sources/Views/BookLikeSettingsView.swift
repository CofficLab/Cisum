import MagicKit
import CisumUIComponents
import LumiUI
import SwiftUI

public struct BookLikeSettingsView: View, SuperLog {
    public nonisolated static var emoji: String { "❤️" }
    private static var verbose: Bool { false }

    @ObservedObject private var viewModel: BookLikeViewModel

    init(viewModel: BookLikeViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 16) {
                header

                if viewModel.isLoading {
                    ProgressView {
                        Text(Self.loadingText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.likedBooks.isEmpty {
                    emptyState
                } else {
                    List(viewModel.likedBooks) { book in
                        row(book)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            viewModel.handleAppear()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Liked Books", bundle: .module)
                .font(.appTitle)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No liked books yet", bundle: .module)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ book: BookLikeItem) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(book.title)
                    .font(.body)
                Text(book.url.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }
}

extension BookLikeSettingsView {
    nonisolated static var loadingTextKey: String { "Loading..." }

    private static var loadingText: String {
        String(localized: String.LocalizationValue(loadingTextKey), bundle: .module)
    }
}

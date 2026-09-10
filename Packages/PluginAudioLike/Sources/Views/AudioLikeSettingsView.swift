import CisumUIComponents
import SwiftUI
import ProviderAudioLike

public struct AudioLikeSettingsView: View, SuperLog {
    public nonisolated static var emoji: String { "⚙️❤️" }

    @ObservedObject private var viewModel: AudioLikeViewModel

    init(viewModel: AudioLikeViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 16) {
                header

                if viewModel.isLoading {
                    ProgressView {
                        Text("Loading...", bundle: .module)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.likedAudios.isEmpty {
                    emptyState
                } else {
                    List(viewModel.likedAudios, id: \.audioId) { audio in
                        row(audio)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            viewModel.reloadLikedAudios()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Liked audio", bundle: .module)
                .font(.appTitle)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No liked audio yet", bundle: .module)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ audio: AudioLikeItem) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(audio.title ?? audio.url?.lastPathComponent ?? String(localized: "Unknown audio", bundle: .module))
                    .font(.body)
                if let url = audio.url {
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }
}

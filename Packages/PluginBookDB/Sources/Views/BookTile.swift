import CisumUIComponents
import OSLog
import ProviderBook
import ProviderBook
import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct BookTileLoadIdentity: Equatable {
    let bookURL: URL
    let dbRoot: URL
    let stateRevision: Int
}

enum BookTileColorPolicy {
    private static let offsetBasis: UInt64 = 14_695_981_039_346_656_037
    private static let prime: UInt64 = 1_099_511_628_211

    static func hue(for title: String) -> Double {
        let hash = title.unicodeScalars.reduce(offsetBasis) { partialResult, scalar in
            (partialResult ^ UInt64(scalar.value)) &* prime
        }
        return Double(hash % 360) / 360
    }

    static func background(for title: String, colorScheme: ColorScheme) -> Color {
        Color(
            hue: hue(for: title),
            saturation: colorScheme == .dark ? 0.55 : 0.6,
            brightness: colorScheme == .dark ? 0.42 : 0.72
        )
    }
}

enum BookTileStateRefreshPolicy {
    static func shouldReloadTile(bookURL: URL, updatedBookURL: URL?) -> Bool {
        guard let updatedBookURL else { return false }
        return BookPlaybackOrdering.representsSameFile(bookURL, updatedBookURL)
    }

    static func nextRevision(after revision: Int) -> Int {
        revision + 1
    }
}

/**
 * Purpose: display book data read from the database as a tile with cover art and basic information.
 * Properties:
 *   - url: book URL path
 *   - title: book title
 *   - childCount: number of audio files contained in the book
 *   - cover: book cover image loaded asynchronously
 *   - state: playback state that records the last playback position
 * Usage: shown in the book list with cover art, title, file count, and playback history.
 */
struct BookTile: View, SuperThread, SuperLog, Equatable {
    nonisolated static func == (lhs: BookTile, rhs: BookTile) -> Bool {
        lhs.url == rhs.url
    }

    @EnvironmentObject var viewModel: BookGridViewModel
    @Environment(\.bookDBViewDependencies) private var dependencies
    @Environment(\.colorScheme) private var colorScheme

    @State private var lastPlayedTitle: String? = nil
    @State private var cover: Image? = nil
    @State private var tileSize: CGSize = .init(width: 150, height: 200)
    @State private var stateRevision: Int = 0

    nonisolated static let emoji = "🖥️"
    private let verbose = true
    
    private var noCover: Bool { cover == nil }
    
    var url: URL
    var title: String
    var childCount: Int

    var body: some View {
        ZStack {
            if let cover = cover {
                cover
                    .resizable()
                    .scaledToFill()
                    .frame(width: tileSize.width, height: tileSize.height)
                    .clipped()
            } else {
                BookTileColorPolicy.background(for: title, colorScheme: colorScheme)
            }

            HStack {
                Spacer()
                VStack {
                    Spacer()

                    if noCover {
                        Text(title)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.7)
                            .shadow(color: .black.opacity(0.24), radius: 2, y: 1)
                            .padding(.horizontal, 10)
                    }

                    Spacer()

                    if childCount > 0, noCover {
                        Text("Total \(childCount)", bundle: .module)
                    }

                    Spacer()
                    if let lastPlayedTitle, noCover {
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "info")
                                Text("Last played", bundle: .module)
                            }
                            Text(lastPlayedTitle)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                        }
                        .font(.footnote)
                        .padding()
                    }
                }
                Spacer()
            }
            .foregroundStyle(noCover ? Color.white : Color.primary)
        }
        .frame(width: tileSize.width)
        .frame(height: tileSize.height)
        .task(id: BookTileLoadIdentity(bookURL: url, dbRoot: dependencies.dbRoot, stateRevision: stateRevision)) {
            await loadTileData()
        }
        .onChange(of: viewModel.lastStateUpdatedURL) { _, updatedURL in
            guard BookTileStateRefreshPolicy.shouldReloadTile(bookURL: url, updatedBookURL: updatedURL) else {
                return
            }
            stateRevision = BookTileStateRefreshPolicy.nextRevision(after: stateRevision)
        }
    }
}

// MARK: - Action

extension BookTile {
    @MainActor
    func loadTileData() async {
        cover = nil
        lastPlayedTitle = nil

        guard let bookProvider = dependencies.bookProvider else { return }

        let bookURL = url
        let bookTitle = title
        let logPrefix = t

        if verbose {
            os_log("\(logPrefix)Loading cover art for \(bookTitle)")
        }

        let coverData = await bookProvider.coverData(for: bookURL)
        let playbackState = await bookProvider.playbackState(for: bookURL)

        guard !Task.isCancelled else {
            return
        }

        cover = Self.image(from: coverData)
        lastPlayedTitle = playbackState?.currentURL?.lastPathComponent
    }

    private static func image(from data: Data?) -> Image? {
        guard let data else { return nil }
#if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
#elseif os(iOS)
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
#else
        return nil
#endif
    }
}

// MARK: - Preview

#if os(macOS)

#endif

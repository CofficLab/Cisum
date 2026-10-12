import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

struct AudioContentViewShowcase: View {
    private static let errorURL = URL(string: "invalid://url")
        ?? URL(fileURLWithPath: "invalid-url")

    var body: some View {
        TabView {
            // Basic Usage - Verbose
            VStack(spacing: 12) {
                Text("Basic Usage (Verbose)")
                    .font(.headline)
                    .padding(.top)

                AudioContentView(
                    asset: .init(
                        url: .documentsDirectory,
                        metadata: .init(
                            title: "Test Song",
                            artist: "Test Artist",
                            album: "Test Album"
                        )
                    ),
                    verbose: true
                )
                .frame(width: 400)
            }
            .tabItem {
                Label("Verbose", systemImage: "speaker.wave.2")
            }

            // Basic Usage - Non-Verbose
            VStack(spacing: 12) {
                Text("Basic Usage (Non-Verbose)")
                    .font(.headline)
                    .padding(.top)

                AudioContentView(
                    asset: .init(
                        url: .documentsDirectory,
                        metadata: .init(
                            title: "Test Song",
                            artist: "Test Artist",
                            album: "Test Album"
                        )
                    ),
                    verbose: false
                )
                .frame(width: 400)
            }
            .tabItem {
                Label("Quiet", systemImage: "speaker.slash")
            }

            // External Artwork
            VStack(spacing: 12) {
                Text("External Artwork")
                    .font(.headline)
                    .padding(.top)

                AudioContentView(
                    asset: .init(
                        url: .documentsDirectory,
                        metadata: .init(
                            title: "Song with Cover",
                            artist: "Artist Name",
                            album: "Album Name"
                        )
                    ),
                    artwork: Image(systemName: "music.note"),
                    verbose: false
                )
                .frame(width: 400)

                Text("Pass custom artwork using the artwork parameter")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .tabItem {
                Label("External Cover", systemImage: "photo")
            }

            // Default Cover Image
            VStack(spacing: 12) {
                Text("Default Cover Image")
                    .font(.headline)
                    .padding(.top)

                AudioContentView(
                    asset: .init(
                        url: .documentsDirectory,
                        metadata: .init(
                            title: "Song with Default Cover",
                            artist: "Artist Name",
                            album: "Album Name"
                        )
                    ),
                    defaultArtwork: Image(systemName: "photo.artframe"),
                    verbose: false
                )
                .frame(width: 400)

                Text("Set default artwork using the defaultArtwork parameter")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .tabItem {
                Label("Default Cover", systemImage: "photo.artframe")
            }

            // Priority: External > Local > Default
            VStack(spacing: 12) {
                Text("Priority: External > Local > Default")
                    .font(.headline)
                    .padding(.top)

                AudioContentView(
                    asset: .init(
                        url: .documentsDirectory,
                        metadata: .init(
                            title: "Song with Both Covers",
                            artist: "Artist Name",
                            album: "Album Name"
                        )
                    ),
                    artwork: Image(systemName: "music.note"),
                    defaultArtwork: Image(systemName: "photo.artframe"),
                    verbose: false
                )
                .frame(width: 400)

                Text("External cover has highest priority, default cover as fallback")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .tabItem {
                Label("Priority", systemImage: "arrow.up.arrow.down")
            }

            // Loading State
            VStack(spacing: 12) {
                Text("Loading State")
                    .font(.headline)
                    .padding(.top)

                AudioContentView(
                    asset: .init(
                        url: .documentsDirectory,
                        metadata: .init(
                            title: "Loading...",
                            artist: "Unknown Artist",
                            album: "Unknown Album"
                        )
                    ),
                    verbose: false
                )
                .frame(width: 400)

                Text("Show Loading Indicator")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .tabItem {
                Label("Loading", systemImage: "clock")
            }

            // Error State
            VStack(spacing: 12) {
                Text("Error State (No Default Cover)")
                    .font(.headline)
                    .padding(.top)

                let errorAsset = MagicAsset(
                    url: Self.errorURL,
                    metadata: .init(
                        title: "Error Test",
                        artist: "Error Artist",
                        album: "Error Album"
                    )
                )

                AudioContentView(asset: errorAsset)
                    .frame(width: 400, height: 500)

                Text("Show Error Message and Retry Button")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .tabItem {
                Label("Error", systemImage: "exclamationmark.triangle")
            }

            // Error State with Default Cover
            VStack(spacing: 12) {
                Text("Error State (With Default Cover)")
                    .font(.headline)
                    .padding(.top)

                let errorAsset = MagicAsset(
                    url: Self.errorURL,
                    metadata: .init(
                        title: "Error with Default",
                        artist: "Error Artist",
                        album: "Error Album"
                    )
                )

                AudioContentView(
                    asset: errorAsset,
                    defaultArtwork: Image(systemName: "exclamationmark.triangle")
                )
                .frame(width: 400, height: 500)

                Text("Use the default cover as a fallback")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .tabItem {
                Label("Fallback", systemImage: "exclamationmark.shield")
            }
        }
        .frame(width: 500, height: 600)
    }
}

#Preview("AudioContentView Showcase") {
    AudioContentViewShowcase()
}

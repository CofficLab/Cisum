import CisumUIComponents
import LumiUI
import MagicKit
import OSLog
import SwiftUI

struct AudioPlayerViewShowcase: View {
    var body: some View {
        TabView {
            // Basic Usage
            VStack(spacing: 12) {
                Text("Basic Usage")
                    .font(.headline)
                    .padding(.top)

                AudioPlayerView(
                    title: "Test Song",
                    artist: "Test Artist",
                    url: .documentsDirectory
                )
                .frame(width: 400)
            }
            .tabItem {
                Label("Basic", systemImage: "music.note")
            }

            // With Default Cover
            VStack(spacing: 12) {
                Text("With Default Cover")
                    .font(.headline)
                    .padding(.top)

                AudioPlayerView(
                    title: "Song with Cover",
                    artist: "Artist Name",
                    url: .documentsDirectory,
                    defaultArtwork: Image(systemName: "photo.artframe")
                )
                .frame(width: 400)

                Text("Use the defaultArtwork parameter")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tabItem {
                Label("Default Cover", systemImage: "photo.artframe")
            }

            // No Artist Info
            VStack(spacing: 12) {
                Text("No Artist Info")
                    .font(.headline)
                    .padding(.top)

                AudioPlayerView(
                    title: "Unknown Artist Song",
                    url: .documentsDirectory,
                    defaultArtwork: Image(systemName: "music.note")
                )
                .frame(width: 400)

                Text("Artist parameter is nil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tabItem {
                Label("No Artist", systemImage: "person.slash")
            }

            // No URL
            VStack(spacing: 12) {
                Text("No URL (Empty State)")
                    .font(.headline)
                    .padding(.top)

                AudioPlayerView(
                    title: "No Media",
                    artist: "Select media to play",
                    url: nil,
                    defaultArtwork: Image(systemName: "doc.questionmark")
                )
                .frame(width: 400)

                Text("URL parameter is nil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tabItem {
                Label("Empty State", systemImage: "doc.questionmark")
            }
        }
        .frame(width: 500, height: 600)
    }
}

#Preview("AudioPlayerView Showcase") {
    AudioPlayerViewShowcase()
}

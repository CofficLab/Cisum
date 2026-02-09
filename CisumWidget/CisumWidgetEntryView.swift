import SwiftUI
import WidgetKit
import AppIntents

struct CisumWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var data: WidgetData {
        entry.data
    }
    
    var body: some View {
        ZStack {
            // Background
            if let coverData = data.coverArtData, let image = platformImage(from: coverData) {
                Image(platformImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(.black.opacity(0.4))
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 255/255, green: 140/255, blue: 0/255), // DarkOrange
                        Color(red: 148/255, green: 0/255, blue: 211/255)  // DarkViolet
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            VStack {
                Spacer()
                
                // Info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(data.title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(data.artist)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                Spacer()
                    .frame(height: 10)
                
                // Controls
                HStack(spacing: 30) {
                    if family != .systemSmall {
                        Button(intent: PreviousTrackIntent()) {
                            Image(systemName: "backward.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(intent: PlayPauseIntent()) {
                        Image(systemName: data.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    if family != .systemSmall {
                        Button(intent: NextTrackIntent()) {
                            Image(systemName: "forward.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .containerBackground(for: .widget) {
            Color.black // Fallback background
        }
    }
}

extension View {
    // Helper to conditionally apply containerBackground for iOS 17+
    @ViewBuilder
    func widgetBackground(_ backgroundView: some View) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            background(backgroundView)
        }
    }
}

#Preview(as: .systemSmall) {
    CisumWidget()
} timeline: {
    SimpleEntry(date: .now, data: .empty)
    SimpleEntry(date: .now, data: WidgetData(title: "Preview Song", artist: "Artist", isPlaying: true, coverArtData: nil))
}

#Preview(as: .systemMedium) {
    CisumWidget()
} timeline: {
    SimpleEntry(date: .now, data: WidgetData(title: "Preview Song", artist: "Artist", isPlaying: true, coverArtData: nil))
}

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

extension View {
    func platformImage(from data: Data) -> PlatformImage? {
        PlatformImage(data: data)
    }
}

extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

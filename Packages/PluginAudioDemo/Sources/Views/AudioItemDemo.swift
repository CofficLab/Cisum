import Foundation
import SwiftUI

public struct AudioItemDemo: View {
    public let url: URL

    public static let iconNames: [String] = [
        "music.note",
        "music.note.list",
        "music.quarternote.3",
        "music.mic",
        "waveform",
        "waveform.circle",
        "speaker.wave.2",
        "headphones",
    ]

    private var iconName: String {
        let index = Self.stableIndex(for: url.hashValue, count: Self.iconNames.count)
        return Self.iconNames[index]
    }

    private var iconColor: Color {
        let colors: [Color] = [
            .blue,
            .purple,
            .pink,
            .orange,
            .green,
            .teal,
            .cyan,
            .indigo,
        ]
        let index = Self.stableIndex(for: url.hashValue, count: colors.count)
        return colors[index]
    }

    nonisolated static func stableIndex(for hashValue: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }

        let remainder = hashValue % count
        return remainder >= 0 ? remainder : remainder + count
    }

    private var sizeText: String {
        switch url.pathExtension.lowercased() {
        case "mp3":
            return "4.2 MB"
        case "m4a":
            return "3.8 MB"
        case "flac":
            return "25.6 MB"
        case "wav":
            return "12.4 MB"
        default:
            return "5.0 MB"
        }
    }

    public init(_ url: URL) {
        self.url = url
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)

                Text(sizeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

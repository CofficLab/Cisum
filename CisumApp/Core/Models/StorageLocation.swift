import Foundation
import SwiftUI

// MARK: - StorageLocation

enum StorageLocation: String, Codable {
    case icloud
    case local
    case custom

    var emojiTitle: String {
        self.emoji + " " + self.title
    }

    var emoji: String {
        switch self {
        case .icloud: return "🌐"
        case .local: return "💾"
        case .custom: return "🔧"
        }
    }

    var title: String {
        switch self {
        case .icloud: return "iCloud"
        case .local: return "Local"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .icloud: return "Use iCloud for data storage"
        case .local: return "Use local storage for data"
        case .custom: return "Use custom storage location for data"
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}

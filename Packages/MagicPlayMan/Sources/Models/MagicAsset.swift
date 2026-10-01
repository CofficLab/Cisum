import Foundation
import SwiftUI
import CisumUIComponents
import LumiUI
import MagicKit

public struct MagicAsset: Identifiable, Equatable {
    public let id = UUID()
    public let url: URL
    public let metadata: Metadata
    
    public init(url: URL, metadata: Metadata) {
        self.url = url
        self.metadata = metadata
    }
    
    public struct Metadata: Equatable {
        public let title: String
        public let artist: String?
        public let album: String?
        public let artwork: Image?
        public let duration: TimeInterval
        
        public init(
            title: String,
            artist: String? = nil,
            album: String? = nil,
            artwork: Image? = nil,
            duration: TimeInterval = 0
        ) {
            self.title = title
            self.artist = artist
            self.album = album
            self.artwork = artwork
            self.duration = duration
        }
    }
    
    // MARK: - Computed Properties
    
    public var title: String {
        metadata.title
    }
    
    public var artist: String? {
        metadata.artist
    }
    
    public var album: String? {
        metadata.album
    }
    
    public var artwork: Image? {
        metadata.artwork
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: MagicAsset, rhs: MagicAsset) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Preview Helpers

extension MagicAsset {
    static var preview: MagicAsset {
        MagicAsset(
            url: .documentsDirectory,
            metadata: .init(
                title: "Preview Song",
                artist: "Preview Artist",
                album: "Preview Album"
            )
        )
    }
}

// MARK: - Preview
#Preview("MagicPlayMan") {
    MagicPlayMan.getPreviewView()
}

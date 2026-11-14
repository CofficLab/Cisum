import Foundation
import SwiftUI
import UniformTypeIdentifiers

public extension URL {
    var defaultImage: Image {
        Image(systemName: systemIcon)
    }

    var fastDefaultImage: Image {
        Image(systemName: fastIcon)
    }

    var isAudio: Bool {
        if let type = try? resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type.conforms(to: .audio)
        }

        return Self.audioExtSet.contains(pathExtension.lowercased())
    }

    var isVideo: Bool {
        if let type = try? resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type.conforms(to: .audiovisualContent) && !type.conforms(to: .audio)
        }

        return Self.videoExtSet.contains(pathExtension.lowercased())
    }

    var isImage: Bool {
        if let type = try? resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type.conforms(to: .image)
        }

        return Self.imageExtSet.contains(pathExtension.lowercased())
    }

    var isDocument: Bool {
        if let type = try? resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type.conforms(to: .data)
        }

        return Self.documentExtSet.contains(pathExtension.lowercased())
    }

    var isNetworkURL: Bool {
        scheme == "http" || scheme == "https"
    }

    var isFileExist: Bool {
        isFileURL ? FileManager.default.fileExists(atPath: path) : true
    }

    var icon: String {
        if isAudio { return "music.note" }
        if isVideo { return "film" }
        if isImage { return "photo" }
        if isFolder { return "folder" }
        if isDocument { return "doc.text" }
        if isNetworkURL { return "globe" }
        return "doc"
    }

    var systemIcon: String {
        icon
    }

    var fastIcon: String {
        let ext = pathExtension.lowercased()
        if Self.audioExtSet.contains(ext) { return "music.note" }
        if Self.videoExtSet.contains(ext) { return "film" }
        if Self.imageExtSet.contains(ext) { return "photo" }
        if hasDirectoryPath { return "folder" }
        return "doc"
    }

    func checkIsDownloaded(verbose: Bool = false) -> Bool {
        isDownloaded
    }

    private static let audioExtSet: Set<String> = [
        "mp3", "m4a", "m4b", "aac", "wav", "aiff", "aif", "wma",
        "ogg", "oga", "opus", "flac", "alac", "mid", "midi", "ac3"
    ]

    private static let videoExtSet: Set<String> = [
        "mp4", "m4v", "mov", "avi", "wmv", "flv", "mkv", "webm",
        "3gp", "mpeg", "mpg", "ts", "mts", "m2ts", "vob", "ogv",
        "m3u8", "m3u"
    ]

    private static let imageExtSet: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp",
        "heic", "heif", "raw", "svg", "ico"
    ]

    private static let documentExtSet: Set<String> = [
        "pdf", "doc", "docx", "txt", "rtf", "pages", "md", "json",
        "xml", "csv"
    ]
}
